package com.condolives.api.service;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.condolives.api.dto.amenity.AmenityDetailResponse;
import com.condolives.api.dto.amenity.AmenityResponse;
import com.condolives.api.dto.amenity.CreateAmenityRequest;
import com.condolives.api.dto.amenity.CreateExceptionRequest;
import com.condolives.api.dto.amenity.ExceptionResponse;
import com.condolives.api.dto.amenity.ScheduleResponse;
import com.condolives.api.dto.amenity.SetScheduleRequest;
import com.condolives.api.dto.amenity.UpdateAmenityRequest;
import com.condolives.api.entity.Amenity.Amenity;
import com.condolives.api.entity.Amenity.AmenityException;
import com.condolives.api.entity.Amenity.AmenitySchedule;
import com.condolives.api.exception.ServiceException;
import com.condolives.api.repository.Amenity.AmenityExceptionRepository;
import com.condolives.api.repository.Amenity.AmenityRepository;
import com.condolives.api.repository.Amenity.AmenityScheduleRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class AmenityService {

    private final AmenityRepository amenityRepository;
    private final AmenityScheduleRepository scheduleRepository;
    private final AmenityExceptionRepository exceptionRepository;

    @Transactional
    public AmenityResponse create(CreateAmenityRequest request, UUID condominiumId) {
        if (amenityRepository.existsByCondominiumIdAndNameIgnoreCase(condominiumId, request.name())) {
            throw new ServiceException("Já existe um espaço com este nome no condomínio", 409);
        }

        Amenity amenity = Amenity.builder()
                .condominiumId(condominiumId)
                .name(request.name())
                .maxCapacity(request.maxCapacity())
                .description(request.description())
                .active(true)
                .build();

        return AmenityResponse.from(amenityRepository.save(amenity));
    }

    public List<AmenityResponse> list(UUID condominiumId, Boolean activeOnly) {
        List<Amenity> amenities = Boolean.TRUE.equals(activeOnly)
                ? amenityRepository.findAllByCondominiumIdAndActiveOrderByName(condominiumId, true)
                : amenityRepository.findAllByCondominiumIdOrderByName(condominiumId);

        return amenities.stream().map(AmenityResponse::from).toList();
    }

    public AmenityDetailResponse getDetail(UUID id, UUID condominiumId) {
        Amenity amenity = findOrThrow(id, condominiumId);

        var schedules = scheduleRepository.findAllByAmenityIdOrderByDayOfWeek(id);
        var exceptions = exceptionRepository
                .findAllByAmenityIdAndDateGreaterThanEqualOrderByDate(id, LocalDate.now());

        return AmenityDetailResponse.from(amenity, schedules, exceptions);
    }

    @Transactional
    public AmenityResponse update(UUID id, UpdateAmenityRequest request, UUID condominiumId) {
        Amenity existing = findOrThrow(id, condominiumId);

        String newName = request.name() != null ? request.name() : existing.getName();

        if (request.name() != null && !request.name().equalsIgnoreCase(existing.getName())
                && amenityRepository.existsByCondominiumIdAndNameIgnoreCase(condominiumId, request.name())) {
            throw new ServiceException("Já existe um espaço com este nome no condomínio", 409);
        }

        Amenity updated = Amenity.builder()
                .id(existing.getId())
                .condominiumId(existing.getCondominiumId())
                .name(newName)
                .maxCapacity(request.maxCapacity() != null ? request.maxCapacity() : existing.getMaxCapacity())
                .description(request.description() != null ? request.description() : existing.getDescription())
                .active(request.active() != null ? request.active() : existing.getActive())
                .build();

        return AmenityResponse.from(amenityRepository.save(updated));
    }

    @Transactional
    public ScheduleResponse setSchedule(UUID amenityId, short dayOfWeek, SetScheduleRequest request, UUID condominiumId) {
        if (dayOfWeek < 0 || dayOfWeek > 6) {
            throw new ServiceException("Dia da semana deve ser entre 0 (domingo) e 6 (sábado)", 422);
        }

        findOrThrow(amenityId, condominiumId);

        if (!request.closed() && (request.opensAt() == null || request.closesAt() == null)) {
            throw new ServiceException("Horários de abertura e fechamento são obrigatórios quando o espaço está aberto", 422);
        }

        if (!request.closed() && !request.closesAt().isAfter(request.opensAt())) {
            throw new ServiceException("Horário de fechamento deve ser posterior ao de abertura", 422);
        }

        var existing = scheduleRepository.findByAmenityIdAndDayOfWeek(amenityId, dayOfWeek);

        AmenitySchedule schedule = AmenitySchedule.builder()
                .id(existing.map(AmenitySchedule::getId).orElse(null))
                .amenityId(amenityId)
                .dayOfWeek(dayOfWeek)
                .closed(request.closed())
                .opensAt(request.closed() ? null : request.opensAt())
                .closesAt(request.closed() ? null : request.closesAt())
                .build();

        return ScheduleResponse.from(scheduleRepository.save(schedule));
    }

    @Transactional
    public void deleteSchedule(UUID amenityId, short dayOfWeek, UUID condominiumId) {
        findOrThrow(amenityId, condominiumId);
        scheduleRepository.deleteByAmenityIdAndDayOfWeek(amenityId, dayOfWeek);
    }

    @Transactional
    public ExceptionResponse addException(UUID amenityId, CreateExceptionRequest request, UUID condominiumId) {
        findOrThrow(amenityId, condominiumId);

        if (exceptionRepository.existsByAmenityIdAndDate(amenityId, request.date())) {
            throw new ServiceException("Já existe uma exceção cadastrada para esta data", 409);
        }

        if (!request.closed() && (request.opensAt() == null || request.closesAt() == null)) {
            throw new ServiceException("Horários de abertura e fechamento são obrigatórios quando o espaço está aberto", 422);
        }

        if (!request.closed() && !request.closesAt().isAfter(request.opensAt())) {
            throw new ServiceException("Horário de fechamento deve ser posterior ao de abertura", 422);
        }

        AmenityException exception = AmenityException.builder()
                .amenityId(amenityId)
                .date(request.date())
                .closed(request.closed())
                .opensAt(request.closed() ? null : request.opensAt())
                .closesAt(request.closed() ? null : request.closesAt())
                .reason(request.reason())
                .build();

        return ExceptionResponse.from(exceptionRepository.save(exception));
    }

    @Transactional
    public void deleteException(UUID amenityId, UUID exceptionId, UUID condominiumId) {
        findOrThrow(amenityId, condominiumId);

        AmenityException exception = exceptionRepository.findById(exceptionId)
                .filter(e -> e.getAmenityId().equals(amenityId))
                .orElseThrow(() -> new ServiceException("Exceção não encontrada", 404));

        exceptionRepository.delete(exception);
    }

    private Amenity findOrThrow(UUID id, UUID condominiumId) {
        return amenityRepository.findByIdAndCondominiumId(id, condominiumId)
                .orElseThrow(() -> new ServiceException("Espaço não encontrado", 404));
    }
}

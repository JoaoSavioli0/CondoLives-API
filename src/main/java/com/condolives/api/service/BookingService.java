package com.condolives.api.service;

import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.condolives.api.dto.booking.BookingResponse;
import com.condolives.api.dto.booking.CreateBookingRequest;
import com.condolives.api.entity.Amenity.Amenity;
import com.condolives.api.entity.Amenity.AmenityException;
import com.condolives.api.entity.Amenity.AmenitySchedule;
import com.condolives.api.entity.Amenity.Booking;
import com.condolives.api.enums.BookingStatus;
import com.condolives.api.exception.ServiceException;
import com.condolives.api.repository.Amenity.AmenityExceptionRepository;
import com.condolives.api.repository.Amenity.AmenityRepository;
import com.condolives.api.repository.Amenity.AmenityScheduleRepository;
import com.condolives.api.repository.Amenity.BookingRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class BookingService {

    private final AmenityRepository amenityRepository;
    private final AmenityScheduleRepository scheduleRepository;
    private final AmenityExceptionRepository exceptionRepository;
    private final BookingRepository bookingRepository;

    @Transactional
    public BookingResponse create(CreateBookingRequest request, UUID residentId, UUID condominiumId) {
        Amenity amenity = amenityRepository
                .findByIdAndCondominiumId(request.amenityId(), condominiumId)
                .orElseThrow(() -> new ServiceException("Espaço não encontrado", 404));

        if (!amenity.getActive()) {
            throw new ServiceException("Espaço inativo, reservas não são aceitas", 422);
        }

        if (request.endTime().equals(request.startTime()) || request.endTime().isBefore(request.startTime())) {
            throw new ServiceException("Horário de término deve ser posterior ao de início", 422);
        }

        LocalTime opensAt;
        LocalTime closesAt;

        // Exceção do dia tem prioridade sobre o horário semanal
        var exception = exceptionRepository.findByAmenityIdAndDate(amenity.getId(), request.date());
        if (exception.isPresent()) {
            AmenityException ex = exception.get();
            if (ex.getClosed()) {
                throw new ServiceException("Espaço fechado nesta data: " + formatReason(ex.getReason()), 422);
            }
            opensAt = ex.getOpensAt();
            closesAt = ex.getClosesAt();
        } else {
            short dayOfWeek = toPosixDayOfWeek(request.date().getDayOfWeek());
            AmenitySchedule schedule = scheduleRepository
                    .findByAmenityIdAndDayOfWeek(amenity.getId(), dayOfWeek)
                    .orElseThrow(() -> new ServiceException("Espaço não tem horário configurado para este dia da semana", 422));

            if (schedule.getClosed()) {
                throw new ServiceException("Espaço fechado neste dia da semana", 422);
            }
            opensAt = schedule.getOpensAt();
            closesAt = schedule.getClosesAt();
        }

        if (opensAt != null && request.startTime().isBefore(opensAt)) {
            throw new ServiceException("Horário de início anterior à abertura do espaço (" + opensAt + ")", 422);
        }
        if (closesAt != null && request.endTime().isAfter(closesAt)) {
            throw new ServiceException("Horário de término posterior ao fechamento do espaço (" + closesAt + ")", 422);
        }

        if (request.guestCount() != null && request.guestCount() > amenity.getMaxCapacity()) {
            throw new ServiceException(
                    "Número de convidados (" + request.guestCount() + ") excede a capacidade do espaço (" + amenity.getMaxCapacity() + ")", 422);
        }

        List<Booking> conflicts = bookingRepository.findOverlapping(
                amenity.getId(), request.date(), request.startTime(), request.endTime(), BookingStatus.CANCELADO);
        if (!conflicts.isEmpty()) {
            throw new ServiceException("Já existe uma reserva neste horário para o espaço selecionado", 409);
        }

        Booking booking = Booking.builder()
                .amenityId(amenity.getId())
                .residentId(residentId)
                .date(request.date())
                .startTime(request.startTime())
                .endTime(request.endTime())
                .guestCount(request.guestCount())
                .status(BookingStatus.PENDENTE)
                .build();

        return BookingResponse.from(bookingRepository.save(booking), amenity);
    }

    public List<BookingResponse> listMyBookings(UUID residentId, UUID condominiumId) {
        return bookingRepository
                .findByResidentIdOrderByDateDescStartTimeDesc(residentId)
                .stream()
                .map(b -> amenityRepository
                        .findByIdAndCondominiumId(b.getAmenityId(), condominiumId)
                        .map(a -> BookingResponse.from(b, a))
                        .orElse(null))
                .filter(b -> b != null)
                .toList();
    }

    // Converte DayOfWeek ISO (Mon=1..Sun=7) para POSIX (Sun=0..Sat=6)
    private short toPosixDayOfWeek(DayOfWeek dayOfWeek) {
        return (short) (dayOfWeek.getValue() % 7);
    }

    private String formatReason(String reason) {
        return reason != null ? reason : "sem motivo informado";
    }
}

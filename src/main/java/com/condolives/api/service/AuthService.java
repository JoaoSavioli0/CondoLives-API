package com.condolives.api.service;

import java.time.LocalDate;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.condolives.api.dto.auth.LoginRequest;
import com.condolives.api.dto.auth.LoginResponse;
import com.condolives.api.dto.auth.RegisterRequest;
import com.condolives.api.entity.User.Resident;
import com.condolives.api.exception.ServiceException;
import com.condolives.api.repository.CondominiumRepository;
import com.condolives.api.repository.User.ResidentRepository;
import com.condolives.api.security.JwtTokenProvider;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final ResidentRepository residentRepository;
    private final CondominiumRepository condominiumRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    public LoginResponse login(LoginRequest request) {
        var resident = residentRepository
                .findByEmailAndCondominiumId(request.email(), request.condominiumId())
                .orElseThrow(() -> new ServiceException("Email ou condomínio não encontrados", 404));

        if (!resident.getActive()) {
            throw new ServiceException("Conta desativada", 403);
        }

        if (!passwordEncoder.matches(request.password(), resident.getPasswordHash())) {
            throw new ServiceException("Credenciais inválidas", 401);
        }

        String token = jwtTokenProvider.generateToken(resident);

        return new LoginResponse(
                token,
                "Bearer",
                resident.getName(),
                resident.getEmail(),
                resident.getUnitAddress(),
                resident.getCondominiumId());
    }

    public LoginResponse register(RegisterRequest request) {
        if (!condominiumRepository.existsById(request.condominiumId())) {
            throw new ServiceException("Condomínio não encontrado", 404);
        }

        if (residentRepository.existsByEmailAndCondominiumId(request.email(), request.condominiumId())) {
            throw new ServiceException("E-mail já cadastrado neste condomínio", 409);
        }

        if (residentRepository.existsByCpfAndCondominiumId(request.cpf(), request.condominiumId())) {
            throw new ServiceException("CPF já cadastrado neste condomínio", 409);
        }

        Resident resident = Resident.builder()
                .condominiumId(request.condominiumId())
                .name(request.name())
                .email(request.email())
                .cpf(request.cpf())
                .rg(request.rg())
                .phone(request.phone())
                .unitAddress(request.unitAddress())
                .guardianId(request.guardianId())
                .passwordHash(passwordEncoder.encode(request.password()))
                .joinedAt(LocalDate.now())
                .active(true)
                .build();

        Resident saved = residentRepository.save(resident);
        String token = jwtTokenProvider.generateToken(saved);

        return new LoginResponse(
                token,
                "Bearer",
                saved.getName(),
                saved.getEmail(),
                saved.getUnitAddress(),
                saved.getCondominiumId());
    }
}

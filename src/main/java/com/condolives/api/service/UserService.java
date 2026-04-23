package com.condolives.api.service;

import java.util.UUID;

import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import com.condolives.api.dto.resident.ResidentResponse;
import com.condolives.api.exception.ServiceException;
import com.condolives.api.repository.User.ResidentRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class UserService implements UserDetailsService {

    private final ResidentRepository residentRepository;

    @Override
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
        return residentRepository.findFirstByEmail(email)
                .map(r -> User.withUsername(r.getEmail())
                        .password(r.getPasswordHash())
                        .authorities("ROLE_RESIDENT")
                        .build())
                .orElseThrow(() -> new UsernameNotFoundException("Morador não encontrado: " + email));
    }

    public ResidentResponse getProfile(UUID residentId) {
        return residentRepository.findById(residentId)
                .map(ResidentResponse::from)
                .orElseThrow(() -> new ServiceException("Morador não encontrado", 404));
    }
}

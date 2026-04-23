package com.condolives.api.repository.User;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.condolives.api.entity.User.Resident;

public interface ResidentRepository extends JpaRepository<Resident, UUID> {

    // usado pelo UserDetailsService (login por e-mail sem escopo de condomínio)
    Optional<Resident> findFirstByEmail(String email);

    // usado pelo AuthService (login completo com condomínio)
    Optional<Resident> findByEmailAndCondominiumId(String email, UUID condominiumId);

    boolean existsByEmailAndCondominiumId(String email, UUID condominiumId);

    boolean existsByCpfAndCondominiumId(String cpf, UUID condominiumId);
}

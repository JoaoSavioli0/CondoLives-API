package com.condolives.api.dto.resident;

import java.time.LocalDate;
import java.util.UUID;

import com.condolives.api.entity.User.Resident;

public record ResidentResponse(
        UUID      id,
        UUID      condominiumId,
        String    name,
        String    email,
        String    cpf,
        String    rg,
        String    phone,
        String    unitAddress,
        String    avatarUrl,
        UUID      guardianId,
        LocalDate joinedAt,
        Boolean   active
) {
    public static ResidentResponse from(Resident r) {
        return new ResidentResponse(
                r.getId(),
                r.getCondominiumId(),
                r.getName(),
                r.getEmail(),
                r.getCpf(),
                r.getRg(),
                r.getPhone(),
                r.getUnitAddress(),
                r.getAvatarUrl(),
                r.getGuardianId(),
                r.getJoinedAt(),
                r.getActive()
        );
    }
}

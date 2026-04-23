package com.condolives.api.dto.auth;

import java.util.UUID;

public record LoginResponse(
                String token,
                String type,
                String name,
                String email,
                String unitAddress,
                UUID condominiumId) {
}

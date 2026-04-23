package com.condolives.api.dto.auth;

import java.util.UUID;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @NotNull                                          UUID   condominiumId,
        @NotBlank                                         String name,
        @NotBlank @Email                                  String email,
        @NotBlank @Size(min = 8)                          String password,
        @NotBlank @Pattern(regexp = "\\d{11}")            String cpf,
                                                          String rg,
                                                          String phone,
                                                          String unitAddress,
                                                          UUID   guardianId
) {}

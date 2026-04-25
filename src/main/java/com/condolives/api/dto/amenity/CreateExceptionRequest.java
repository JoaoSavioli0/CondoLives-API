package com.condolives.api.dto.amenity;

import java.time.LocalDate;
import java.time.LocalTime;

import jakarta.validation.constraints.NotNull;

public record CreateExceptionRequest(
        @NotNull LocalDate date,
        @NotNull Boolean closed,
        LocalTime opensAt,
        LocalTime closesAt,
        String reason) {
}

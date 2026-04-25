package com.condolives.api.dto.amenity;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.NotNull;

public record CreateAmenityRequest(
        @NotBlank String name,
        @NotNull @Positive Integer maxCapacity,
        String description) {
}

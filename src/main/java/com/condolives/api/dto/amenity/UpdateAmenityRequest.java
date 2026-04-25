package com.condolives.api.dto.amenity;

import jakarta.validation.constraints.Positive;

public record UpdateAmenityRequest(
        String name,
        @Positive Integer maxCapacity,
        String description,
        Boolean active) {
}

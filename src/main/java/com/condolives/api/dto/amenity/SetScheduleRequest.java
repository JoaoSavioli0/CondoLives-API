package com.condolives.api.dto.amenity;

import java.time.LocalTime;

import jakarta.validation.constraints.NotNull;

public record SetScheduleRequest(
        @NotNull Boolean closed,
        LocalTime opensAt,
        LocalTime closesAt) {
}

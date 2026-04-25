package com.condolives.api.dto.booking;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record CreateBookingRequest(
        @NotNull UUID amenityId,
        @NotNull @Future LocalDate date,
        @NotNull LocalTime startTime,
        @NotNull LocalTime endTime,
        @Positive Integer guestCount) {
}

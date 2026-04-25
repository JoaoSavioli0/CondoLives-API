package com.condolives.api.dto.booking;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

import com.condolives.api.entity.Amenity.Amenity;
import com.condolives.api.entity.Amenity.Booking;
import com.condolives.api.enums.BookingStatus;

public record BookingResponse(
        UUID id,
        UUID amenityId,
        String amenityName,
        UUID residentId,
        LocalDate date,
        LocalTime startTime,
        LocalTime endTime,
        Integer guestCount,
        BookingStatus status,
        String statusDescricao,
        Instant createdAt) {

    public static BookingResponse from(Booking b, Amenity amenity) {
        return new BookingResponse(
                b.getId(),
                b.getAmenityId(),
                amenity.getName(),
                b.getResidentId(),
                b.getDate(),
                b.getStartTime(),
                b.getEndTime(),
                b.getGuestCount(),
                b.getStatus(),
                b.getStatus().getDescricao(),
                b.getCreatedAt());
    }
}

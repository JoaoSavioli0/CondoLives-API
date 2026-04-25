package com.condolives.api.dto.amenity;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

import com.condolives.api.entity.Amenity.AmenityException;

public record ExceptionResponse(
        UUID id,
        LocalDate date,
        LocalTime opensAt,
        LocalTime closesAt,
        boolean closed,
        String reason) {

    public static ExceptionResponse from(AmenityException e) {
        return new ExceptionResponse(
                e.getId(),
                e.getDate(),
                e.getOpensAt(),
                e.getClosesAt(),
                e.getClosed(),
                e.getReason());
    }
}

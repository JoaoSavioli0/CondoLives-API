package com.condolives.api.dto.amenity;

import java.util.UUID;

import com.condolives.api.entity.Amenity.Amenity;

public record AmenityResponse(
        UUID id,
        String name,
        int maxCapacity,
        String description,
        boolean active) {

    public static AmenityResponse from(Amenity a) {
        return new AmenityResponse(
                a.getId(),
                a.getName(),
                a.getMaxCapacity(),
                a.getDescription(),
                a.getActive());
    }
}

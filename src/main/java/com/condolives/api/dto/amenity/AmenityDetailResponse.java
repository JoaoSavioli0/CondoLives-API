package com.condolives.api.dto.amenity;

import java.util.List;
import java.util.UUID;

import com.condolives.api.entity.Amenity.Amenity;
import com.condolives.api.entity.Amenity.AmenityException;
import com.condolives.api.entity.Amenity.AmenitySchedule;

public record AmenityDetailResponse(
        UUID id,
        String name,
        int maxCapacity,
        String description,
        boolean active,
        List<ScheduleResponse> schedules,
        List<ExceptionResponse> upcomingExceptions) {

    public static AmenityDetailResponse from(
            Amenity a,
            List<AmenitySchedule> schedules,
            List<AmenityException> exceptions) {
        return new AmenityDetailResponse(
                a.getId(),
                a.getName(),
                a.getMaxCapacity(),
                a.getDescription(),
                a.getActive(),
                schedules.stream().map(ScheduleResponse::from).toList(),
                exceptions.stream().map(ExceptionResponse::from).toList());
    }
}

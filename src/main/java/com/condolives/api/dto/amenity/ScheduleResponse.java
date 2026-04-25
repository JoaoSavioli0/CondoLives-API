package com.condolives.api.dto.amenity;

import java.time.LocalTime;
import java.util.UUID;

import com.condolives.api.entity.Amenity.AmenitySchedule;

public record ScheduleResponse(
        UUID id,
        short dayOfWeek,
        String dayName,
        LocalTime opensAt,
        LocalTime closesAt,
        boolean closed) {

    private static final String[] DAY_NAMES = {
        "Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira",
        "Quinta-feira", "Sexta-feira", "Sábado"
    };

    public static ScheduleResponse from(AmenitySchedule s) {
        return new ScheduleResponse(
                s.getId(),
                s.getDayOfWeek(),
                DAY_NAMES[s.getDayOfWeek()],
                s.getOpensAt(),
                s.getClosesAt(),
                s.getClosed());
    }
}

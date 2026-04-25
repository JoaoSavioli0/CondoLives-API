package com.condolives.api.repository.Amenity;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.condolives.api.entity.Amenity.Booking;
import com.condolives.api.enums.BookingStatus;

public interface BookingRepository extends JpaRepository<Booking, UUID> {

    @Query("""
            SELECT b FROM Booking b
            WHERE b.amenityId = :amenityId
              AND b.date = :date
              AND b.status <> :cancelled
              AND b.startTime < :endTime
              AND b.endTime > :startTime
            """)
    List<Booking> findOverlapping(
            @Param("amenityId") UUID amenityId,
            @Param("date") LocalDate date,
            @Param("startTime") LocalTime startTime,
            @Param("endTime") LocalTime endTime,
            @Param("cancelled") BookingStatus cancelled);

    List<Booking> findByResidentIdOrderByDateDescStartTimeDesc(UUID residentId);
}

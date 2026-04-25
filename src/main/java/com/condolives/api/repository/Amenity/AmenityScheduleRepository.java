package com.condolives.api.repository.Amenity;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.condolives.api.entity.Amenity.AmenitySchedule;

public interface AmenityScheduleRepository extends JpaRepository<AmenitySchedule, UUID> {

    Optional<AmenitySchedule> findByAmenityIdAndDayOfWeek(UUID amenityId, Short dayOfWeek);

    List<AmenitySchedule> findAllByAmenityIdOrderByDayOfWeek(UUID amenityId);

    void deleteByAmenityIdAndDayOfWeek(UUID amenityId, Short dayOfWeek);
}

package com.condolives.api.repository.Amenity;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.condolives.api.entity.Amenity.AmenityException;

public interface AmenityExceptionRepository extends JpaRepository<AmenityException, UUID> {

    Optional<AmenityException> findByAmenityIdAndDate(UUID amenityId, LocalDate date);

    List<AmenityException> findAllByAmenityIdAndDateGreaterThanEqualOrderByDate(UUID amenityId, LocalDate from);

    boolean existsByAmenityIdAndDate(UUID amenityId, LocalDate date);
}

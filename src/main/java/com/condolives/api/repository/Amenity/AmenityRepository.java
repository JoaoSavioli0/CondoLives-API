package com.condolives.api.repository.Amenity;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.condolives.api.entity.Amenity.Amenity;

public interface AmenityRepository extends JpaRepository<Amenity, UUID> {

    Optional<Amenity> findByIdAndCondominiumId(UUID id, UUID condominiumId);

    List<Amenity> findAllByCondominiumIdOrderByName(UUID condominiumId);

    List<Amenity> findAllByCondominiumIdAndActiveOrderByName(UUID condominiumId, Boolean active);

    boolean existsByCondominiumIdAndNameIgnoreCase(UUID condominiumId, String name);
}

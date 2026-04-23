package com.condolives.api.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.condolives.api.entity.Condominium;

public interface CondominiumRepository extends JpaRepository<Condominium, UUID> {
}

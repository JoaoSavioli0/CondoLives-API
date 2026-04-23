package com.condolives.api.entity.User;

import java.time.LocalDate;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "resident")
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
public class Resident {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "condominium_id", nullable = false)
    private UUID condominiumId;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, columnDefinition = "citext")
    private String email;

    @Column(nullable = false, length = 11)
    private String cpf;

    private String rg;

    private String phone;

    @Column(name = "unit_address")
    private String unitAddress;

    @Column(name = "avatar_url")
    private String avatarUrl;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(name = "guardian_id")
    private UUID guardianId;

    @Column(name = "joined_at", nullable = false)
    private LocalDate joinedAt;

    @Column(nullable = false)
    private Boolean active;
}

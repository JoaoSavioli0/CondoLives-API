package com.condolives.api.repository.Post.Ticket;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.condolives.api.entity.Post.Ticket.Category;

public interface CategoryRepository extends JpaRepository<Category, UUID> {

    List<Category> findAllByIdInAndCondominiumId(List<UUID> ids, UUID condominiumId);
}

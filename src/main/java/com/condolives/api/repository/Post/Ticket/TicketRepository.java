package com.condolives.api.repository.Post.Ticket;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.condolives.api.entity.Post.Ticket.Ticket;

public interface TicketRepository extends JpaRepository<Ticket, UUID> {
}

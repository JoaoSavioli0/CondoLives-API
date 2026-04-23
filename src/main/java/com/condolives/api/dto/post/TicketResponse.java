package com.condolives.api.dto.post;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.condolives.api.entity.Post.Ticket.Ticket;
import com.condolives.api.enums.TicketStatus;

public record TicketResponse(
        UUID              id,
        UUID              condominiumId,
        UUID              residentId,
        String            title,
        String            description,
        String            location,
        TicketStatus      status,
        String            statusDescricao,
        List<CategoryDto> categories,
        Instant           createdAt
) {
    public record CategoryDto(UUID id, String name) {}

    public static TicketResponse from(Ticket t) {
        return new TicketResponse(
                t.getId(),
                t.getCondominiumId(),
                t.getResidentId(),
                t.getTitle(),
                t.getDescription(),
                t.getLocation(),
                t.getStatus(),
                t.getStatus().getDescricao(),
                t.getCategories().stream()
                        .map(c -> new CategoryDto(c.getId(), c.getName()))
                        .toList(),
                t.getCreatedAt()
        );
    }
}

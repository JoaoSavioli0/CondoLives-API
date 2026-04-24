package com.condolives.api.dto.post.Ticket;

import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

public record CreateTicketRequest(
                @NotBlank String title,
                String description,
                String location,
                @NotEmpty List<UUID> categoryIds) {
}

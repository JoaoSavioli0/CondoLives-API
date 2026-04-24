package com.condolives.api.controller;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.condolives.api.controller.helpers.PostHelper;
import com.condolives.api.dto.post.Ticket.CreateTicketRequest;
import com.condolives.api.dto.post.Ticket.TicketResponse;
import com.condolives.api.service.TicketService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/ticket")
@RequiredArgsConstructor
public class TicketController {

    private final TicketService ticketService;
    private final PostHelper postHelper;

    @PostMapping
    public ResponseEntity<TicketResponse> create(
            @RequestBody @Valid CreateTicketRequest request,
            Authentication authentication) {

        UUID residentId = UUID.fromString((String) authentication.getPrincipal());
        UUID condominiumId = postHelper.condominiumId(authentication);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ticketService.createTicket(request, residentId, condominiumId));
    }
}

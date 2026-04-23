package com.condolives.api.controller;

import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.condolives.api.dto.post.CreateTicketRequest;
import com.condolives.api.dto.post.TicketResponse;
import com.condolives.api.service.RequestService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/tickets")
@RequiredArgsConstructor
public class RequestController {

    private final RequestService requestService;

    @PostMapping
    public ResponseEntity<TicketResponse> create(
            @RequestBody @Valid CreateTicketRequest request,
            Authentication authentication) {

        UUID residentId     = UUID.fromString((String) authentication.getPrincipal());
        UUID condominiumId  = condominiumId(authentication);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(requestService.createTicket(request, residentId, condominiumId));
    }

    @SuppressWarnings("unchecked")
    private UUID condominiumId(Authentication authentication) {
        var details = (Map<String, Object>) authentication.getDetails();
        return UUID.fromString((String) details.get("condominiumId"));
    }
}

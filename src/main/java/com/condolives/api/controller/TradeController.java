package com.condolives.api.controller;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.condolives.api.service.TradeService;

import lombok.RequiredArgsConstructor;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

import com.condolives.api.controller.helpers.PostHelper;
import com.condolives.api.dto.post.Trade.CreateTradeRequest;
import com.condolives.api.dto.post.Trade.TradeResponse;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/trade")
@RequiredArgsConstructor
public class TradeController {
    private final TradeService tradeService;

    @PostMapping
    public ResponseEntity<TradeResponse> postMethodName(
            @Valid @RequestBody CreateTradeRequest request,
            Authentication authentication) {

        UUID residentId = UUID.fromString((String) authentication.getPrincipal());
        UUID condominiumId = PostHelper.condominiumId(authentication);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(tradeService.createTrade(request, residentId, condominiumId));
    }

}

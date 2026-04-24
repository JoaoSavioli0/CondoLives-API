package com.condolives.api.dto.post.Trade;

import jakarta.validation.constraints.NotBlank;

public record CreateTradeRequest(
                @NotBlank String title,
                String description,
                String tradeType,
                String itemType) {
}

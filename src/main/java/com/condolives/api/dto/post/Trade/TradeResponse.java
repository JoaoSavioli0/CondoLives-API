package com.condolives.api.dto.post.Trade;

import java.time.Instant;
import java.util.UUID;

import com.condolives.api.entity.Post.Trade.Trade;
import com.condolives.api.enums.PostStatus;

public record TradeResponse(
                UUID id,
                UUID condominiumId,
                UUID residentId,
                String title,
                String description,
                String tradeType,
                String itemType,
                PostStatus status,
                String statusDescricao,
                Instant createdAt) {
        public record CategoryDto(UUID id, String name) {
        }

        public static TradeResponse from(Trade t) {
                return new TradeResponse(
                                t.getId(),
                                t.getCondominiumId(),
                                t.getResidentId(),
                                t.getTitle(),
                                t.getDescription(),
                                t.getTradeType(),
                                t.getItemType(),
                                t.getStatus(),
                                t.getStatus().getDescricao(),
                                t.getCreatedAt());
        }
}

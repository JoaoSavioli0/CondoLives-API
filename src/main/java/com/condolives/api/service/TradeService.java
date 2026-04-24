package com.condolives.api.service;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.condolives.api.dto.post.Ticket.CreateTicketRequest;
import com.condolives.api.dto.post.Ticket.TicketResponse;
import com.condolives.api.dto.post.Trade.CreateTradeRequest;
import com.condolives.api.dto.post.Trade.TradeResponse;
import com.condolives.api.entity.Post.Ticket.Category;
import com.condolives.api.entity.Post.Ticket.Ticket;
import com.condolives.api.entity.Post.Trade.Trade;
import com.condolives.api.enums.PostStatus;
import com.condolives.api.exception.ServiceException;
import com.condolives.api.repository.Post.Ticket.CategoryRepository;
import com.condolives.api.repository.Post.Ticket.TicketRepository;
import com.condolives.api.repository.Post.Trade.TradeRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class TradeService {

    private final TradeRepository tradeRepository;

    @Transactional
    public TradeResponse createTrade(CreateTradeRequest request, UUID residentId, UUID condominiumId) {
        Trade trade = Trade.builder()
                .condominiumId(condominiumId)
                .residentId(residentId)
                .visible(true)
                .title(request.title())
                .description(request.description())
                .status(PostStatus.ABERTO)
                .build();

        return TradeResponse.from(tradeRepository.save(trade));
    }
}

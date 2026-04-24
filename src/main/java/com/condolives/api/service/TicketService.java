package com.condolives.api.service;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.condolives.api.dto.post.Ticket.CreateTicketRequest;
import com.condolives.api.dto.post.Ticket.TicketResponse;
import com.condolives.api.entity.Post.Ticket.Category;
import com.condolives.api.entity.Post.Ticket.Ticket;
import com.condolives.api.enums.PostStatus;
import com.condolives.api.exception.ServiceException;
import com.condolives.api.repository.Post.Ticket.CategoryRepository;
import com.condolives.api.repository.Post.Ticket.TicketRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class TicketService {

    private final TicketRepository ticketRepository;
    private final CategoryRepository categoryRepository;

    @Transactional
    public TicketResponse createTicket(CreateTicketRequest request, UUID residentId, UUID condominiumId) {
        List<Category> categories = categoryRepository
                .findAllByIdInAndCondominiumId(request.categoryIds(), condominiumId);

        if (categories.size() != request.categoryIds().size()) {
            throw new ServiceException("Uma ou mais categorias não existem neste condomínio", 422);
        }

        Ticket ticket = Ticket.builder()
                .condominiumId(condominiumId)
                .residentId(residentId)
                .visible(true)
                .title(request.title())
                .description(request.description())
                .location(request.location())
                .status(PostStatus.ABERTO)
                .categories(categories)
                .build();

        return TicketResponse.from(ticketRepository.save(ticket));
    }
}

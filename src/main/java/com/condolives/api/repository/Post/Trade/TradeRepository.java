package com.condolives.api.repository.Post.Trade;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.condolives.api.entity.Post.Trade.Trade;

public interface TradeRepository extends JpaRepository<Trade, UUID> {

}
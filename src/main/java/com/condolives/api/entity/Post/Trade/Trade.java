package com.condolives.api.entity.Post.Trade;

import com.condolives.api.converter.PostStatusConverter;
import com.condolives.api.entity.Post.Post;
import com.condolives.api.enums.PostStatus;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.experimental.SuperBuilder;

@Entity
@Table(name = "trade")
@DiscriminatorValue("trade")
@Getter
@SuperBuilder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Trade extends Post {

    private String title;

    private String description;

    @Column(name = "trade_type", nullable = false)
    private String tradeType;

    @Column(name = "item_type", nullable = false)
    private String itemType;

    @Convert(converter = PostStatusConverter.class)
    private PostStatus status;
}

package com.condolives.api.converter;

import com.condolives.api.enums.PostStatus;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter
public class PostStatusConverter implements AttributeConverter<PostStatus, String> {

    @Override
    public String convertToDatabaseColumn(PostStatus status) {
        return status == null ? null : status.toDbValue();
    }

    @Override
    public PostStatus convertToEntityAttribute(String dbValue) {
        return dbValue == null ? null : PostStatus.fromDbValue(dbValue);
    }
}

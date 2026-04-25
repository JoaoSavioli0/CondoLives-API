package com.condolives.api.converter;

import com.condolives.api.enums.BookingStatus;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter
public class BookingStatusConverter implements AttributeConverter<BookingStatus, String> {

    @Override
    public String convertToDatabaseColumn(BookingStatus status) {
        return status == null ? null : status.toDbValue();
    }

    @Override
    public BookingStatus convertToEntityAttribute(String dbValue) {
        return dbValue == null ? null : BookingStatus.fromDbValue(dbValue);
    }
}

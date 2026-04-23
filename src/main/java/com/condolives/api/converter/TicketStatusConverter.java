package com.condolives.api.converter;

import com.condolives.api.enums.TicketStatus;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter
public class TicketStatusConverter implements AttributeConverter<TicketStatus, String> {

    @Override
    public String convertToDatabaseColumn(TicketStatus status) {
        return status == null ? null : status.toDbValue();
    }

    @Override
    public TicketStatus convertToEntityAttribute(String dbValue) {
        return dbValue == null ? null : TicketStatus.fromDbValue(dbValue);
    }
}

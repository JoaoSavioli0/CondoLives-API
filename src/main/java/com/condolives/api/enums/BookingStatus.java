package com.condolives.api.enums;

public enum BookingStatus {
    PENDENTE("Pendente"),
    CONFIRMADO("Confirmado"),
    CANCELADO("Cancelado");

    private final String descricao;

    BookingStatus(String descricao) {
        this.descricao = descricao;
    }

    public String getDescricao() {
        return descricao;
    }

    public String toDbValue() {
        return switch (this) {
            case PENDENTE   -> "pending";
            case CONFIRMADO -> "confirmed";
            case CANCELADO  -> "cancelled";
        };
    }

    public static BookingStatus fromDbValue(String value) {
        return switch (value) {
            case "pending"   -> PENDENTE;
            case "confirmed" -> CONFIRMADO;
            case "cancelled" -> CANCELADO;
            default -> throw new IllegalArgumentException("Status desconhecido: " + value);
        };
    }
}

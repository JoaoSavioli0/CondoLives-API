package com.condolives.api.enums;

public enum TicketStatus {
    ABERTO("Aberto"),
    EM_ANDAMENTO("Em andamento"),
    CONCLUIDO("Concluído"),
    CANCELADO("Cancelado");

    private final String descricao;

    TicketStatus(String descricao) {
        this.descricao = descricao;
    }

    public String getDescricao() {
        return descricao;
    }

    public String toDbValue() {
        return switch (this) {
            case ABERTO       -> "open";
            case EM_ANDAMENTO -> "in_progress";
            case CONCLUIDO    -> "resolved";
            case CANCELADO    -> "cancelled";
        };
    }

    public static TicketStatus fromDbValue(String value) {
        return switch (value) {
            case "open"        -> ABERTO;
            case "in_progress" -> EM_ANDAMENTO;
            case "resolved"    -> CONCLUIDO;
            case "cancelled"   -> CANCELADO;
            default -> throw new IllegalArgumentException("Status desconhecido: " + value);
        };
    }
}

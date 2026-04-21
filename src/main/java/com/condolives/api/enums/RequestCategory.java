package com.condolives.api.enums;

public enum RequestCategory {

    MANUTENCAO("Manutenção"),
    LIMPEZA("Limpeza"),
    SEGURANCA("Segurança"),
    BARULHO("Barulho"),
    ILUMINACAO("Iluminação"),
    ELEVADOR("Elevador"),
    AREA_COMUM("Área comum"),
    VIZINHANCA("Vizinhança"),
    ADMINISTRATIVO("Administrativo"),
    SUGESTAO("Sugestão"),
    OUTROS("Outros");

    private final String descricao;

    RequestCategory(String descricao) {
        this.descricao = descricao;
    }

    public String getDescricao() {
        return descricao;
    }
}

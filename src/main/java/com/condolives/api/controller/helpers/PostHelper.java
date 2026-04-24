package com.condolives.api.controller.helpers;

import java.util.Map;
import java.util.UUID;

import org.springframework.security.core.Authentication;

public class PostHelper {

    @SuppressWarnings("unchecked")
    public UUID condominiumId(Authentication authentication) {
        var details = (Map<String, Object>) authentication.getDetails();
        return UUID.fromString((String) details.get("condominiumId"));
    }
}

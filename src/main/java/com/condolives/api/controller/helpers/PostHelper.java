package com.condolives.api.controller.helpers;

import java.util.Map;
import java.util.UUID;

import lombok.experimental.Helper;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

public class PostHelper {

    public static UUID condominiumId(Authentication authentication) {
        var details = (Map<String, Object>) authentication.getDetails();
        return UUID.fromString((String) details.get("condominiumId"));
    }
}

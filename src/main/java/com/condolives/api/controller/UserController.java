package com.condolives.api.controller;

import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.condolives.api.dto.resident.ResidentResponse;
import com.condolives.api.service.UserService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/residents")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/me")
    public ResponseEntity<ResidentResponse> me(Authentication authentication) {
        UUID residentId = UUID.fromString((String) authentication.getPrincipal());
        return ResponseEntity.ok(userService.getProfile(residentId));
    }
}

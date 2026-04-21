package com.condolives.api.exception;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ServiceException.class)
    public ResponseEntity<?> handleBusinessException(ServiceException ex) {

        Map<String, Object> body = new HashMap<>();
        body.put("erro", ex.getMessage());
        body.put("status", ex.getStatus());
        body.put("timestamp", LocalDateTime.now());

        return ResponseEntity.status(ex.getStatus()).body(body);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<?> handleGenericException(Exception ex) {

        Map<String, Object> body = new HashMap<>();
        body.put("erro", "Erro interno do servidor");
        body.put("status", 500);
        body.put("timestamp", LocalDateTime.now());

        return ResponseEntity.status(500).body(body);
    }
}

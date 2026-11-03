package ru.ifmo.is.backend.dto.auth;

public record CsrfResponse(
        String headerName,
        String token
) {}

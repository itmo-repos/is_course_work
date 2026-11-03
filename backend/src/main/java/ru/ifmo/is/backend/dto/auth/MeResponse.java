package ru.ifmo.is.backend.dto.auth;

import ru.ifmo.is.backend.security.AuthPrincipal;

import java.util.List;

public record MeResponse(
        Long id,
        AuthPrincipal.AccountType type,
        String email,
        List<String> roles
) {
    public static MeResponse from(AuthPrincipal principal) {
        return new MeResponse(principal.id(), principal.type(), principal.email(), principal.roles());
    }
}

package ru.ifmo.is.backend.security;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;
import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class GatewayKeyHasher {
    private final SecretTokenService tokens;

    public String generate() {
        return "sgw_" + tokens.generate();
    }

    public String hash(String token) {
        return tokens.hash(token);
    }

    public String hashAuthorization(String authorization) {
        if (authorization == null || authorization.length() != 54
                || !authorization.regionMatches(true, 0, "Bearer ", 0, 7)) {
            throw unauthorized();
        }
        String token = authorization.substring(7);
        if (!token.matches("sgw_[A-Za-z0-9_-]{43}")) throw unauthorized();
        return hash(token);
    }

    public ResponseStatusException unauthorized() {
        return new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Неверный или удалённый ключ шлюза");
    }
}

package ru.ifmo.is.backend.security;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;

@Component
public class GatewayKeyHasher {
    private final SecureRandom random = new SecureRandom();

    public String generate() {
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        return "sgw_" + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public String hash(String token) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 недоступен", exception);
        }
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

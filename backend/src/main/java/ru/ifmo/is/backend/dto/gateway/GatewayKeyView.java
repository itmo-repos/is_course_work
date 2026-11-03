package ru.ifmo.is.backend.dto.gateway;

import java.time.OffsetDateTime;

public record GatewayKeyView(Long id, String name, Long chamberId, Long issuedBy, OffsetDateTime issuedAt) {}

package ru.ifmo.is.backend.dto.gateway;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record GatewayKeyRequest(@NotBlank @Size(max = 100) String name) {}

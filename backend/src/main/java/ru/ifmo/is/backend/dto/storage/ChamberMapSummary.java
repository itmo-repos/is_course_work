package ru.ifmo.is.backend.dto.storage;

public record ChamberMapSummary(
        int total,
        int free,
        int reserved,
        int occupied,
        int unserviceable,
        int available
) {}

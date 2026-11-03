package ru.ifmo.is.backend.dto.common;

public record StoredDocument(
        byte[] content,
        String filename,
        String mediaType
) {}

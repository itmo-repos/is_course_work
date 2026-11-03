package ru.ifmo.is.backend.dto.batch;

public record SampleView(
        Long id,
        String accessionCode,
        Long speciesId,
        String latinName,
        String originCountryCode,
        short collectionYear,
        int seedQuantity,
        String note
) {}

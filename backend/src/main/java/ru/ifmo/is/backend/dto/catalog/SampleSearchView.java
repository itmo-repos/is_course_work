package ru.ifmo.is.backend.dto.catalog;

public record SampleSearchView(
        String accessionCode,
        String latinName,
        String localName,
        String originCountry,
        Short collectionYear,
        Integer seedQuantity,
        String depositorName
) {}

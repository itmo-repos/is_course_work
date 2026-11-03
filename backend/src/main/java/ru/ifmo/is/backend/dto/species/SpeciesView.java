package ru.ifmo.is.backend.dto.species;

public record SpeciesView(
        Long id,
        String latinName,
        String localName,
        String family
) {}

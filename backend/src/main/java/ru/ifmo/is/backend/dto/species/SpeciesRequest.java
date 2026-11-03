package ru.ifmo.is.backend.dto.species;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SpeciesRequest(
        @NotBlank @Size(max = 160) String latinName,
        @NotBlank @Size(max = 160) String localName,
        @Size(max = 120) String family
) {}

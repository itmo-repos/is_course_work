package ru.ifmo.is.backend.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.repository.CountryRepository;
import ru.ifmo.is.backend.repository.SpeciesRepository;
import ru.ifmo.is.backend.repository.projections.SampleSearchProjection;
import ru.ifmo.is.backend.services.SampleStorageService;

import java.util.List;

@RestController
@RequestMapping("/api/samples")
@RequiredArgsConstructor
public class SampleController {
    private final SampleStorageService samples;
    private final SpeciesRepository species;
    private final CountryRepository countries;

    @GetMapping
    public List<SampleSearchProjection> search(@RequestParam(required = false) String species,
                                               @RequestParam(required = false) String country) {
        return samples.search(species, country);
    }

    @GetMapping("/species")
    public List<SpeciesView> species() {
        return species.findAll(org.springframework.data.domain.Sort.by("latinName")).stream()
                .map(s -> new SpeciesView(s.getId(), s.getLatinName(), s.getLocalName(), s.getFamily())).toList();
    }

    @GetMapping("/countries")
    public List<CountryView> countries() {
        return countries.findAll(org.springframework.data.domain.Sort.by("name")).stream()
                .map(c -> new CountryView(c.getCode(), c.getName())).toList();
    }

    public record SpeciesView(Long id, String latinName, String localName, String family) {}
    public record CountryView(String code, String name) {}
}

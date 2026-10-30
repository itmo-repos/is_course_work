package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import ru.ifmo.is.backend.entitiy.Country;
import ru.ifmo.is.backend.entitiy.Species;
import ru.ifmo.is.backend.repository.SampleRepository;
import ru.ifmo.is.backend.repository.projections.SampleSearchProjection;

import java.util.List;

@Service
@RequiredArgsConstructor
public class SampleStorageService {
    private final SampleRepository repository;

    public List<SampleSearchProjection> search(Species species, Country country) {
        if (species == null && country == null) {
            throw new IllegalArgumentException("Species or country is required!");
        }
        String speciesName = species == null ? null : species.getLatinName().strip();
        String countryCode = country == null ? null : country.getCode().strip();
        return repository.searchSample(speciesName, countryCode);
    }

}

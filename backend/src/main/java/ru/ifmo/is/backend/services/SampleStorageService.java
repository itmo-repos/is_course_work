package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.repository.SampleRepository;
import ru.ifmo.is.backend.repository.projections.SampleSearchProjection;

import java.util.List;
import java.util.Locale;

@Service
@RequiredArgsConstructor
public class SampleStorageService {
    private final SampleRepository repository;

    @Transactional(readOnly = true)
    public List<SampleSearchProjection> search(String species, String country) {
        species = species == null || species.isBlank() ? null : species.strip();
        country = country == null || country.isBlank() ? null : country.strip().toUpperCase(Locale.ROOT);
        if ((species != null && species.length() > 160)
                || (country != null && !country.matches("[A-Z]{2}"))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Некорректный вид или код страны");
        }
        return repository.searchSample(species, country);
    }
}

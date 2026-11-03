package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.species.SpeciesView;
import ru.ifmo.is.backend.entitiy.Species;
import ru.ifmo.is.backend.repository.SpeciesRepository;
import ru.ifmo.is.backend.security.AuthPrincipal;

@Service
@RequiredArgsConstructor
public class SpeciesService {
    private final DepositorAccessService depositorAccess;
    private final SpeciesRepository species;
    private final JdbcTemplate jdbc;

    @Transactional
    public SpeciesView create(AuthPrincipal principal, String latinName, String localName, String family) {
        depositorAccess.lockActive(principal);
        latinName = normalize(latinName);
        localName = normalize(localName);
        family = family == null || family.isBlank() ? null : normalize(family);

        // Добавление редкое: блокируем запись в справочник до конца транзакции,
        // чтобы два депозитора не создали одинаковый вид одновременно.
        jdbc.execute("LOCK TABLE species IN SHARE ROW EXCLUSIVE MODE");
        if (species.findByLatinNameIgnoreCase(latinName).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Вид с таким латинским названием уже существует");
        }
        Species created = new Species();
        created.setLatinName(latinName);
        created.setLocalName(localName);
        created.setFamily(family);
        species.save(created);
        return new SpeciesView(created.getId(), created.getLatinName(), created.getLocalName(), created.getFamily());
    }

    private String normalize(String value) {
        return value.strip().replaceAll("\\s+", " ");
    }
}

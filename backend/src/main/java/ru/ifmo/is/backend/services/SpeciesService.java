package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.entitiy.Depositor;
import ru.ifmo.is.backend.entitiy.Species;
import ru.ifmo.is.backend.entitiy.enums.DepositorStatus;
import ru.ifmo.is.backend.repository.DepositorRepository;
import ru.ifmo.is.backend.repository.SpeciesRepository;
import ru.ifmo.is.backend.security.AuthPrincipal;

@Service
@RequiredArgsConstructor
public class SpeciesService {
    private final SpeciesRepository species;
    private final DepositorRepository depositors;
    private final JdbcTemplate jdbc;

    @Transactional
    public SpeciesView create(AuthPrincipal principal, String latinName, String localName, String family) {
        if (principal == null || principal.type() != AuthPrincipal.AccountType.DEPOSITOR) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Добавлять виды может только активный депозитор");
        }
        Depositor depositor = depositors.findByIdForUpdate(principal.id()).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Депозитор не найден"));
        if (depositor.getStatus() != DepositorStatus.ACTIVE) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Для добавления вида нужен активный договор");
        }
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

    public record SpeciesView(Long id, String latinName, String localName, String family) {}
}

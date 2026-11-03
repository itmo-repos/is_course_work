package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.entitiy.Batch;
import ru.ifmo.is.backend.repository.BatchRepository;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BatchAccessService {
    private final BatchRepository batches;
    private final AccessService access;

    public Batch find(Long id) {
        return batches.findById(id).orElseThrow(this::notFound);
    }

    // Блокировка живёт до конца транзакции вызывающего бизнес-сервиса.
    @Transactional(propagation = Propagation.MANDATORY)
    public Batch lock(Long id) {
        return batches.findByIdForUpdate(id).orElseThrow(this::notFound);
    }

    public Batch owned(AuthPrincipal principal, Long id) {
        access.requireDepositor(principal);
        Batch batch = find(id);
        requireOwner(principal, batch);
        return batch;
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public Batch lockOwned(AuthPrincipal principal, Long id) {
        access.requireDepositor(principal);
        Batch batch = lock(id);
        requireOwner(principal, batch);
        return batch;
    }

    private void requireOwner(AuthPrincipal principal, Batch batch) {
        if (!batch.getDepositor().getId().equals(principal.id())) {
            throw notFound();
        }
    }

    private ResponseStatusException notFound() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "Партия не найдена");
    }
}

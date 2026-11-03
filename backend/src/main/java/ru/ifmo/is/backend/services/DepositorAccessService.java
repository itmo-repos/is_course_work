package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.entitiy.Depositor;
import ru.ifmo.is.backend.entitiy.enums.DepositorStatus;
import ru.ifmo.is.backend.repository.DepositorRepository;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DepositorAccessService {
    private final DepositorRepository depositors;
    private final AccessService access;

    public Depositor current(AuthPrincipal principal) {
        access.requireDepositor(principal);
        return depositors.findById(principal.id()).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Депозитор не найден"));
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public Depositor lockCurrent(AuthPrincipal principal) {
        access.requireDepositor(principal);
        return depositors.findByIdForUpdate(principal.id()).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Депозитор не найден"));
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public Depositor lockActive(AuthPrincipal principal) {
        Depositor depositor = lockCurrent(principal);
        if (depositor.getStatus() != DepositorStatus.ACTIVE) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Доступно только активному депозитору");
        }
        return depositor;
    }
}

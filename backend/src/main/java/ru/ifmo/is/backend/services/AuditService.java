package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import ru.ifmo.is.backend.entitiy.AuditEvent;
import ru.ifmo.is.backend.repository.AuditEventRepository;
import ru.ifmo.is.backend.security.AuthPrincipal;

@Service
@RequiredArgsConstructor
public class AuditService {
    private final AuditEventRepository events;

    @Transactional(propagation = Propagation.MANDATORY)
    public AuditEvent record(AuthPrincipal actor, String action, String entityType, Long entityId,
                              Long batchId, String message) {
        return record(actor, action, entityType, entityId, batchId, message, null);
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public AuditEvent record(AuthPrincipal actor, String action, String entityType, Long entityId,
                              Long batchId, String message, String details) {
        return save(actor == null ? "GUEST" : actor.type().name(), actor == null ? null : actor.id(),
                action, entityType, entityId, batchId, message, details);
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void gateway(Long keyId, Long readingId, Long chamberId) {
        save("GATEWAY", keyId, "CLIMATE_READING_ADDED", "CLIMATE_READING", readingId, null,
                "Добавлено климатическое измерение", "chamberId=" + chamberId);
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void employee(Long employeeId, String action, String entityType, Long entityId, Long batchId, String message) {
        save("EMPLOYEE", employeeId, action, entityType, entityId, batchId, message, null);
    }

    @Transactional
    public void login(AuthPrincipal actor) {
        record(actor, "LOGIN", "ACCOUNT", actor.id(), null, "Вход в систему");
    }

    @Transactional
    public void logout(AuthPrincipal actor) {
        record(actor, "LOGOUT", "ACCOUNT", actor.id(), null, "Выход из системы");
    }

    private AuditEvent save(String actorType, Long actorId, String action, String entityType,
                              Long entityId, Long batchId, String message, String details) {
        AuditEvent event = new AuditEvent();
        event.setActorType(actorType);
        event.setActorId(actorId);
        event.setAction(action);
        event.setEntityType(entityType);
        event.setEntityId(entityId);
        event.setBatchId(batchId);
        event.setMessage(message);
        event.setDetails(details);
        return events.save(event);
    }
}

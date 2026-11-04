package ru.ifmo.is.backend.dto.pass;

import ru.ifmo.is.backend.entitiy.enums.AccessDirection;
import java.time.OffsetDateTime;

public record AccessEventView(Long id, Long passId, Long employeeId, Long chamberId,
                              AccessDirection direction, OffsetDateTime occurredAt, String comment,
                              Long registeredBy) {}

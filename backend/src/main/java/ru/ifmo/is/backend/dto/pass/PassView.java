package ru.ifmo.is.backend.dto.pass;

import ru.ifmo.is.backend.entitiy.enums.PassStatus;
import java.time.OffsetDateTime;
import java.util.List;

public record PassView(Long id, Long employeeId, Long issuedBy, Long intakeSessionId,
                       PassStatus status, OffsetDateTime validFrom, OffsetDateTime validTo, String comment,
                       Long revokedBy, OffsetDateTime revokedAt, List<Long> chamberIds) {}

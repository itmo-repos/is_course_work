package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;
import java.time.ZoneOffset;

@Entity
@Table(name = "audit_event")
@Getter @Setter @NoArgsConstructor
public class AuditEvent {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "actor_type", nullable = false)
    private String actorType;
    @Column(name = "actor_id")
    private Long actorId;
    @Column(nullable = false)
    private String action;
    @Column(name = "entity_type", nullable = false)
    private String entityType;
    @Column(name = "entity_id")
    private Long entityId;
    @Column(name = "batch_id")
    private Long batchId;
    @Column(nullable = false)
    private String message;
    private String details;
    @Column(name = "occurred_at", nullable = false)
    private LocalDateTime occurredAt = LocalDateTime.now(ZoneOffset.UTC);
}

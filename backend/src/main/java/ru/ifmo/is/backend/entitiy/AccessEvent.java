package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import ru.ifmo.is.backend.entitiy.enums.AccessDirection;

import java.time.LocalDateTime;
import java.time.ZoneOffset;

@Entity
@Table(name = "access_event")
@Getter @Setter @NoArgsConstructor
public class AccessEvent {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "pass_id", nullable = false)
    private VaultPass pass;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "employee_id")
    private Employee employee;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "chamber_id", nullable = false)
    private Chamber chamber;
    @Enumerated(EnumType.STRING) @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(nullable = false, columnDefinition = "access_direction")
    private AccessDirection direction;
    @Column(name = "occurred_at", nullable = false)
    private LocalDateTime occurredAt = LocalDateTime.now(ZoneOffset.UTC);
    private String comment;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "registered_by")
    private Employee registeredBy;
}

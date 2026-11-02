package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import ru.ifmo.is.backend.entitiy.enums.SessionStatus;

import java.time.LocalDate;
import java.time.OffsetDateTime;

@Entity
@Table(name = "intake_session")
@Getter @Setter
@NoArgsConstructor
public class IntakeSession {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "batch_id", nullable = false, unique = true)
    private Batch batch;

    @ManyToOne
    @JoinColumn(name = "curator_id", nullable = false)
    private Employee curator;

    @ManyToOne
    @JoinColumn(name = "chamber_id", nullable = false)
    private Chamber chamber;

    @Column(name = "planned_date", nullable = false)
    private LocalDate plannedDate;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "status", nullable = false, columnDefinition = "session_status")
    private SessionStatus status = SessionStatus.PLANNED;

    @Column(name = "completed_at")
    private OffsetDateTime completedAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();
}

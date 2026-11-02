package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import ru.ifmo.is.backend.entitiy.enums.WithdrawalStatus;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "withdrawal_request")
@Getter @Setter
@NoArgsConstructor
public class WithdrawalRequest {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "depositor_id", nullable = false)
    private Depositor depositor;

    @ManyToOne
    @JoinColumn(name = "batch_id", nullable = false)
    private Batch batch;

    @Column(name = "reason", nullable = false)
    private String reason;

    @Column(name = "desired_date", nullable = false)
    private LocalDate desiredDate;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(name = "status", nullable = false, columnDefinition = "withdrawal_status")
    private WithdrawalStatus status = WithdrawalStatus.SUBMITTED;

    @Column(name = "submitted_at", nullable = false, updatable = false)
    private OffsetDateTime submittedAt = OffsetDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    @ManyToOne
    @JoinColumn(name = "curator_id")
    private Employee curator;

    @Column(name = "curator_decision_at")
    private OffsetDateTime curatorDecisionAt;

    @ManyToOne
    @JoinColumn(name = "admin_id")
    private Employee admin;

    @Column(name = "admin_decision_at")
    private OffsetDateTime adminDecisionAt;

    @Column(name = "rejection_reason")
    private String rejectionReason;

    @ManyToMany
    @JoinTable(name = "withdrawal_request_box",
            joinColumns = @JoinColumn(name = "request_id"),
            inverseJoinColumns = @JoinColumn(name = "box_id"))
    @OrderBy("id ASC")
    private List<Box> boxes = new ArrayList<>();
}

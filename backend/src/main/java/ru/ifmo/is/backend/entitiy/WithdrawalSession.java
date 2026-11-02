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
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "withdrawal_session")
@Getter @Setter
@NoArgsConstructor
public class WithdrawalSession {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "request_id", nullable = false, unique = true)
    private WithdrawalRequest request;

    @ManyToOne
    @JoinColumn(name = "curator_id", nullable = false)
    private Employee curator;

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

    @ManyToMany
    @JoinTable(name = "withdrawal_session_box",
            joinColumns = @JoinColumn(name = "session_id"),
            inverseJoinColumns = @JoinColumn(name = "box_id"))
    @OrderBy("id ASC")
    private List<Box> boxes = new ArrayList<>();
}

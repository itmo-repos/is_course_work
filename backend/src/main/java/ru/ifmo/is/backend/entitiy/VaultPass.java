package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import ru.ifmo.is.backend.entitiy.enums.PassStatus;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashSet;
import java.util.Set;

@Entity
@Table(name = "vault_pass")
@Getter @Setter @NoArgsConstructor
public class VaultPass {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "code_hash", nullable = false, unique = true, length = 64)
    private String codeHash;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "employee_id")
    private Employee employee;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "issued_by", nullable = false)
    private Employee issuedBy;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "intake_session_id")
    private IntakeSession intakeSession;
    @Enumerated(EnumType.STRING) @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(nullable = false, columnDefinition = "pass_status")
    private PassStatus status = PassStatus.ACTIVE;
    @Column(name = "valid_from", nullable = false)
    private LocalDateTime validFrom;
    @Column(name = "valid_to")
    private LocalDateTime validTo;
    private String comment;
    @ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name = "revoked_by")
    private Employee revokedBy;
    @Column(name = "revoked_at")
    private LocalDateTime revokedAt;
    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now(ZoneOffset.UTC);
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt = LocalDateTime.now(ZoneOffset.UTC);
    @ManyToMany
    @JoinTable(name = "pass_chamber", joinColumns = @JoinColumn(name = "pass_id"),
            inverseJoinColumns = @JoinColumn(name = "chamber_id"))
    private Set<Chamber> chambers = new LinkedHashSet<>();
}

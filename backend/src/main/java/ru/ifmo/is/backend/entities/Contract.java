package ru.ifmo.is.backend.entities;

import jakarta.persistence.*;
import lombok.*;
import ru.ifmo.is.backend.entities.enums.ContractStatus;
import java.time.LocalDate;
import java.time.OffsetDateTime;

@Entity
@Table(name = "contract")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
public class Contract {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "depositor_id", nullable = false)
    private Depositor depositor;

    @Column(name = "number", length = 40, nullable = false, unique = true)
    private String number;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private ContractStatus status = ContractStatus.GENERATED;

    @Column(name = "generated_at", nullable = false, updatable = false)
    private OffsetDateTime generatedAt = OffsetDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    @Column(name = "generated_doc_uri", length = 512)
    private String generatedDocUri;

    @Column(name = "signed_scan_uri", length = 512)
    private String signedScanUri;

    @Column(name = "signed_uploaded_at")
    private OffsetDateTime signedUploadedAt;

    @ManyToOne
    @JoinColumn(name = "verified_by")
    private Employee verifiedBy;

    @Column(name = "verified_at")
    private OffsetDateTime verifiedAt;

    @Column(name = "rejection_reason")
    private String rejectionReason;

    @Column(name = "valid_from")
    private LocalDate validFrom;

    @Column(name = "valid_to")
    private LocalDate validTo;
}

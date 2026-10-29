package ru.ifmo.is.backend.entities;

import jakarta.persistence.*;
import lombok.*;
import ru.ifmo.is.backend.entities.enums.BatchStatus;
import java.time.LocalDate;
import java.time.OffsetDateTime;

@Entity
@Table(name = "batch")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
public class Batch {

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
    private BatchStatus status = BatchStatus.FORMED;

    @Column(name = "formed_at", nullable = false, updatable = false)
    private OffsetDateTime formedAt = OffsetDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    @Column(name = "desired_shipment_date", nullable = false)
    private LocalDate desiredShipmentDate;

    @ManyToOne
    @JoinColumn(name = "confirmed_by")
    private Employee confirmedBy;

    @Column(name = "confirmed_at")
    private OffsetDateTime confirmedAt;

    @Column(name = "rejection_reason")
    private String rejectionReason;

    @Column(name = "tracking_number", length = 64)
    private String trackingNumber;

    @Column(name = "arrived_at")
    private OffsetDateTime arrivedAt;
}

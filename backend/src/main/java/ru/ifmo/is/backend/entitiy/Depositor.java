package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import lombok.*;
import ru.ifmo.is.backend.entitiy.enums.DepositorStatus;
import java.time.OffsetDateTime;

@Entity
@Table(name = "depositor")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
public class Depositor {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "legal_name", length = 300, nullable = false, unique = true)
    private String legalName;

    @ManyToOne
    @JoinColumn(name = "country_code", nullable = false)
    private Country country;

    @Column(name = "registration_number", length = 64, nullable = false)
    private String registrationNumber;

    @Column(name = "legal_address", columnDefinition = "text", nullable = false)
    private String legalAddress;

    @Column(name = "contact_person", length = 200, nullable = false)
    private String contactPerson;

    @Column(name = "contact_email", length = 254, nullable = false, unique = true)
    private String contactEmail;

    @Column(name = "contact_phone", length = 32)
    private String contactPhone;

    @Column(name = "password_hash", length = 255, nullable = false)
    private String passwordHash;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private DepositorStatus status = DepositorStatus.NEW_REQUEST;

    @Column(name = "rejection_reason", columnDefinition = "text")
    private String rejectionReason;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();
}

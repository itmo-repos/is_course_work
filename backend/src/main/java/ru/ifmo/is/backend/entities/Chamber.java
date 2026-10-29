package ru.ifmo.is.backend.entities;

import jakarta.persistence.*;
import lombok.*;
import ru.ifmo.is.backend.entities.enums.ChamberStatus;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "chamber")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
public class Chamber {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "code", length = 20, nullable = false, unique = true)
    private String code;

    @Column(name = "name", length = 160, nullable = false)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private ChamberStatus status = ChamberStatus.ACTIVE;

    @Column(name = "climate_controlled", nullable = false)
    private boolean climateControlled = true;

    @Column(name = "min_temperature", precision = 5, scale = 2)
    private BigDecimal minTemperature;

    @Column(name = "max_temperature", precision = 5, scale = 2)
    private BigDecimal maxTemperature;

    @Column(name = "min_humidity", precision = 5, scale = 2)
    private BigDecimal minHumidity;

    @Column(name = "max_humidity", precision = 5, scale = 2)
    private BigDecimal maxHumidity;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();
}

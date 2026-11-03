package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "climate_reading")
@Getter @Setter @NoArgsConstructor
public class ClimateReading {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chamber_id", nullable = false)
    private Chamber chamber;

    // В существующей БД timestamp без зоны. Для новых показаний храним здесь UTC.
    @Column(name = "measured_at", nullable = false)
    private LocalDateTime measuredAt;

    @Column(nullable = false, precision = 5, scale = 2)
    private BigDecimal temperature;

    @Column(nullable = false, precision = 5, scale = 2)
    private BigDecimal humidity;
}

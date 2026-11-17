package ru.ifmo.is.backend.dto.report;

import ru.ifmo.is.backend.entitiy.enums.ChamberStatus;
import java.math.BigDecimal;

public record OccupancyReportRow(Long chamberId, String code, String name, ChamberStatus status,
        long total, long free, long reserved, long occupied, long unserviceable, long available,
        BigDecimal occupiedPercent, BigDecimal assignedPercent) {}

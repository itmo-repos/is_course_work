package ru.ifmo.is.backend.dto.report;

import java.time.OffsetDateTime;
import java.util.List;

public record ReportView<T>(OffsetDateTime generatedAt, List<T> items, long total, int page, int size) {}

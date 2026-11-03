package ru.ifmo.is.backend.dto.common;

import java.util.List;

public record PageView<T>(List<T> items, long total, int page, int size) {}

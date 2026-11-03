package ru.ifmo.is.backend.dto.batch;

import ru.ifmo.is.backend.entitiy.enums.BoxStatus;

import java.util.List;

public record BoxView(
        Long id,
        short seqNo,
        BoxStatus status,
        String barcode,
        List<SampleView> samples
) {}

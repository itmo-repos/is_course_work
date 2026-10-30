package ru.ifmo.is.backend.services;

import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import ru.ifmo.is.backend.repository.BoxRepository;
import ru.ifmo.is.backend.repository.projections.BatchBarcodeProjection;

@Service
@RequiredArgsConstructor
public class BoxStorageService {
    private final BoxRepository repository;

    public BatchBarcodeProjection getBatchByBarcode(String barcode) {
        BatchBarcodeProjection batchBarcodeProjection = repository.identifyBatchByBarcode(barcode);
        if (batchBarcodeProjection == null) {
            throw new EntityNotFoundException("Batch with barcode " + barcode + " not found, try another box!");
        }
        return batchBarcodeProjection;
    }

}

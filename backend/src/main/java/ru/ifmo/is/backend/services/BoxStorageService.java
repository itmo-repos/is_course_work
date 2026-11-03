package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.batch.BatchIdentificationView;
import ru.ifmo.is.backend.repository.BoxRepository;
import ru.ifmo.is.backend.repository.projections.BatchBarcodeProjection;

@Service
@RequiredArgsConstructor
public class BoxStorageService {
    private final BoxRepository repository;

    public BatchIdentificationView getBatchByBarcode(String barcode) {
        BatchBarcodeProjection batchBarcodeProjection = repository.identifyBatchByBarcode(barcode);
        if (batchBarcodeProjection == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Партия по штрихкоду не найдена");
        }
        return new BatchIdentificationView(
                batchBarcodeProjection.getBatchId(), batchBarcodeProjection.getBatchNumber(),
                batchBarcodeProjection.getDepositorName(), batchBarcodeProjection.getCurrentStatus(),
                batchBarcodeProjection.getBoxCount());
    }
}

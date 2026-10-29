package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ru.ifmo.is.backend.entitiy.Box;
import ru.ifmo.is.backend.repository.projections.BatchBarcodeProjection;

public interface BoxRepository extends JpaRepository<Box, Long> {

    @Query(value = "SELECT * FROM identify_batch_by_barcode(:barcode)", nativeQuery = true)
    BatchBarcodeProjection identifyBatchByBarcode(@Param("barcode") String barcode);

}

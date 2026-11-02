package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ru.ifmo.is.backend.entitiy.Box;
import ru.ifmo.is.backend.repository.projections.BatchBarcodeProjection;

import java.util.List;
import java.util.Optional;

public interface BoxRepository extends JpaRepository<Box, Long> {

    List<Box> findAllByBatch_IdOrderBySeqNoAsc(Long batchId);

    @Query("select b.batch.id from Box b where b.id = :id")
    Optional<Long> findBatchIdById(@Param("id") Long id);

    boolean existsByStoragePlace_IdAndIdNot(Long placeId, Long boxId);

    @Query(value = "SELECT * FROM identify_batch_by_barcode(:barcode)", nativeQuery = true)
    BatchBarcodeProjection identifyBatchByBarcode(@Param("barcode") String barcode);

}

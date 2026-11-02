package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ru.ifmo.is.backend.entitiy.IntakeSession;

import java.util.Optional;

public interface IntakeSessionRepository extends JpaRepository<IntakeSession, Long> {
    Optional<IntakeSession> findByBatch_Id(Long batchId);
    boolean existsByBatch_Id(Long batchId);

    @Query("select s.batch.id from IntakeSession s where s.id = :id")
    Optional<Long> findBatchIdById(@Param("id") Long id);
}

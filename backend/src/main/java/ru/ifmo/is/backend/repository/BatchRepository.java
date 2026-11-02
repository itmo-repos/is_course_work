package ru.ifmo.is.backend.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ru.ifmo.is.backend.entitiy.Batch;
import ru.ifmo.is.backend.entitiy.enums.BatchStatus;

import java.util.List;
import java.util.Optional;

public interface BatchRepository extends JpaRepository<Batch, Long> {
    @Query(value = "SELECT nextval('batch_number_seq')", nativeQuery = true)
    long nextNumber();

    List<Batch> findAllByDepositor_IdOrderByFormedAtDesc(Long depositorId);
    List<Batch> findAllByStatusOrderByFormedAtAsc(BatchStatus status);
    List<Batch> findAllByOrderByFormedAtAsc();

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select b from Batch b where b.id = :id")
    Optional<Batch> findByIdForUpdate(@Param("id") Long id);
}

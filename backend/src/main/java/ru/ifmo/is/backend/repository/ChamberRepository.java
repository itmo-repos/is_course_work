package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import ru.ifmo.is.backend.entitiy.Chamber;
import ru.ifmo.is.backend.entitiy.enums.ChamberStatus;

import java.util.List;
import java.util.Optional;

public interface ChamberRepository extends JpaRepository<Chamber, Long> {
    List<Chamber> findAllByStatusOrderByCodeAsc(ChamberStatus status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from Chamber c where c.id = :id")
    Optional<Chamber> findByIdForUpdate(@Param("id") Long id);
}

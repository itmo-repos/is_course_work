package ru.ifmo.is.backend.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.ClimateReading;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface ClimateReadingRepository extends JpaRepository<ClimateReading, Long> {
    Optional<ClimateReading> findFirstByChamber_IdOrderByMeasuredAtDesc(Long chamberId);

    Optional<ClimateReading> findByChamber_IdAndMeasuredAt(Long chamberId, LocalDateTime measuredAt);

    Page<ClimateReading> findByChamber_IdAndMeasuredAtBetweenOrderByMeasuredAtAsc(
            Long chamberId, LocalDateTime from, LocalDateTime to, Pageable pageable);

    List<ClimateReading> findByChamber_IdAndMeasuredAtBetweenOrderByMeasuredAtAsc(
            Long chamberId, LocalDateTime from, LocalDateTime to);
}

package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.Chamber;

public interface ChamberRepository extends JpaRepository<Chamber, Long> {
}

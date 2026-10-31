package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.Depositor;

import java.util.Optional;

public interface DepositorRepository extends JpaRepository<Depositor, Long> {
    Optional<Depositor> findByContactEmailIgnoreCase(String contactEmail);
}

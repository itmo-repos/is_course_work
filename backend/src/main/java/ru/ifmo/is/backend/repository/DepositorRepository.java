package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.Depositor;

public interface DepositorRepository extends JpaRepository<Depositor, Long> {
}

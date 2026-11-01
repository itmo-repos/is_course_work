package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.Contract;

import java.util.Optional;

public interface ContractRepository extends JpaRepository<Contract, Long> {
    Optional<Contract> findFirstByDepositor_IdOrderByGeneratedAtDesc(Long depositorId);
}

package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.Contract;

public interface ContractRepository extends JpaRepository<Contract, Long> {
}

package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.Species;

public interface SpeciesRepository extends JpaRepository<Species, Long> {
}

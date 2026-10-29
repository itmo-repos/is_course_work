package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.StoragePlace;

public interface StoragePlaceRepository extends JpaRepository<StoragePlace, Long> {
}

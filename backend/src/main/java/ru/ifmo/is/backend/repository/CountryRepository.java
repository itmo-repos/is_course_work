package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.Country;

public interface CountryRepository extends JpaRepository<Country, String> { // Ключ String, так как ID — char(2)
}

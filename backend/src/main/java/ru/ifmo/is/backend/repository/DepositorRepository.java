package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ru.ifmo.is.backend.entitiy.Depositor;
import ru.ifmo.is.backend.entitiy.enums.DepositorStatus;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;

public interface DepositorRepository extends JpaRepository<Depositor, Long> {
    Optional<Depositor> findByContactEmailIgnoreCase(String contactEmail);
    Optional<Depositor> findByLegalNameIgnoreCase(String legalName);
    boolean existsByCountry_CodeAndRegistrationNumber(String countryCode, String registrationNumber);
    List<Depositor> findAllByStatusOrderByCreatedAtAsc(DepositorStatus status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select d from Depositor d where d.id = :id")
    Optional<Depositor> findByIdForUpdate(@Param("id") Long id);
}

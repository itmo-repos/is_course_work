package ru.ifmo.is.backend.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.Notification;

import java.util.Optional;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    Page<Notification> findByEmployee_IdOrderByCreatedAtDescIdDesc(Long employeeId, Pageable pageable);

    Page<Notification> findByEmployee_IdAndReadFalseOrderByCreatedAtDescIdDesc(Long employeeId, Pageable pageable);

    Optional<Notification> findByIdAndEmployee_Id(Long id, Long employeeId);
}

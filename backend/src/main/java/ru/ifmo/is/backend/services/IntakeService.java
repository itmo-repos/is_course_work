package ru.ifmo.is.backend.services;

import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.batch.BatchIdentificationView;
import ru.ifmo.is.backend.dto.storage.ChamberView;
import ru.ifmo.is.backend.dto.storage.IntakeSessionView;
import ru.ifmo.is.backend.dto.storage.StoragePlaceView;
import ru.ifmo.is.backend.dto.storage.StoredBoxView;
import ru.ifmo.is.backend.entitiy.*;
import ru.ifmo.is.backend.entitiy.enums.*;
import ru.ifmo.is.backend.mapper.StoragePlaceMapper;
import ru.ifmo.is.backend.repository.*;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class IntakeService {
    private final BatchRepository batches;
    private final BatchAccessService batchAccess;
    private final StoragePlaceMapper placeMapper;
    private final BoxRepository boxes;
    private final IntakeSessionRepository sessions;
    private final StoragePlaceRepository places;
    private final ChamberRepository chambers;
    private final AccessService access;
    private final BoxStorageService boxStorage;
    private final EntityManager entityManager;

    public BatchIdentificationView identify(AuthPrincipal principal, String barcode) {
        access.requireRole(principal, RoleCode.CURATOR);
        return boxStorage.getBatchByBarcode(barcode.strip());
    }

    @Transactional
    public BatchIdentificationView arrive(AuthPrincipal principal, String barcode) {
        access.requireRole(principal, RoleCode.CURATOR);
        Long batchId = boxStorage.getBatchByBarcode(barcode.strip()).batchId();
        Batch batch = batchAccess.lock(batchId);
        if (batch.getStatus() != BatchStatus.ARRIVED) {
            throw conflict("Для досмотра партия должна быть в статусе ARRIVED");
        }
        IntakeSession session = sessionFor(batch);
        if (session.getStatus() != SessionStatus.PLANNED) {
            throw conflict("Сессия приёма должна быть запланирована");
        }
        if (session.getPlannedDate().isAfter(LocalDate.now())) {
            throw conflict("Дата сессии приёма ещё не наступила");
        }
        lockActiveChamber(session.getChamber().getId());
        List<Box> batchBoxes = formedBoxes(batchId);
        List<StoragePlace> freePlaces = places.reserveFreePlaces(session.getChamber().getId(), batchBoxes.size());
        if (freePlaces.size() != batchBoxes.size()) {
            throw conflict("В камере недостаточно свободных исправных мест; измените камеру запланированной сессии");
        }
        for (int i = 0; i < batchBoxes.size(); i++) {
            Box box = batchBoxes.get(i);
            box.setStoragePlace(freePlaces.get(i));
            box.setStatus(BoxStatus.AWAITING_PLACEMENT);
        }
        batch.setStatus(BatchStatus.INSPECTION);
        batches.flush();
        return boxStorage.getBatchByBarcode(barcode.strip());
    }

    @Transactional
    public IntakeSessionView createSession(AuthPrincipal principal, Long batchId, Long chamberId, LocalDate plannedDate) {
        Employee curator = access.requireEmployee(principal, RoleCode.CURATOR);
        Batch batch = batchAccess.lock(batchId);
        requireBeforeInspection(batch);
        if (sessions.existsByBatch_Id(batchId)) {
            throw conflict("У партии уже есть сессия приёма");
        }
        Chamber chamber = lockActiveChamber(chamberId);
        formedBoxes(batchId);
        IntakeSession session = new IntakeSession();
        session.setBatch(batch);
        session.setCurator(curator);
        session.setChamber(chamber);
        session.setPlannedDate(plannedDate);
        sessions.save(session);
        return sessionView(session);
    }

    @Transactional
    public IntakeSessionView updateSession(AuthPrincipal principal, Long id, Long chamberId, LocalDate plannedDate) {
        access.requireRole(principal, RoleCode.CURATOR);
        Long batchId = sessions.findBatchIdById(id).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Сессия приёма не найдена"));
        Batch batch = batchAccess.lock(batchId);
        requireBeforeInspection(batch);
        IntakeSession session = sessionFor(batch);
        if (session.getStatus() != SessionStatus.PLANNED) {
            throw conflict("Менять план можно только до начала приёма");
        }
        session.setChamber(lockActiveChamber(chamberId));
        session.setPlannedDate(plannedDate);
        return sessionView(session);
    }

    private void requireBeforeInspection(Batch batch) {
        if (batch.getStatus() != BatchStatus.CONFIRMED && batch.getStatus() != BatchStatus.IN_TRANSIT
                && batch.getStatus() != BatchStatus.ARRIVED) {
            throw conflict("Планировать приём можно после подтверждения партии и до начала досмотра");
        }
    }

    private List<Box> formedBoxes(Long batchId) {
        List<Box> batchBoxes = boxes.findAllByBatch_IdOrderBySeqNoAsc(batchId);
        if (batchBoxes.isEmpty()) {
            throw conflict("В партии нет коробок");
        }
        for (Box box : batchBoxes) {
            if (box.getStatus() != BoxStatus.FORMED || box.getStoragePlace() != null) {
                throw conflict("До начала приёма коробки должны быть в статусе FORMED без места хранения");
            }
        }
        return batchBoxes;
    }

    public IntakeSessionView getSession(AuthPrincipal principal, Long id) {
        access.requireRole(principal, RoleCode.CURATOR);
        IntakeSession session = sessions.findById(id).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Сессия приёма не найдена"));
        return sessionView(session);
    }

    public List<ChamberView> listChambers(AuthPrincipal principal, boolean includeInactive) {
        access.requireRole(principal, RoleCode.CURATOR);
        List<ChamberView> result = new ArrayList<>();
        List<Chamber> selected = includeInactive ? chambers.findAllByOrderByCodeAsc()
                : chambers.findAllByStatusOrderByCodeAsc(ChamberStatus.ACTIVE);
        for (Chamber chamber : selected) {
            int available = chamber.getStatus() == ChamberStatus.ACTIVE ? places.findFreePlaces(chamber.getId()).size() : 0;
            result.add(new ChamberView(chamber.getId(), chamber.getCode(), chamber.getName(), chamber.getStatus(), available));
        }
        return result;
    }

    public List<StoragePlaceView> freePlaces(AuthPrincipal principal, Long chamberId) {
        access.requireRole(principal, RoleCode.CURATOR);
        Chamber chamber = chambers.findById(chamberId).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Камера не найдена"));
        if (chamber.getStatus() != ChamberStatus.ACTIVE) {
            throw conflict("Камера неактивна");
        }
        List<StoragePlaceView> result = new ArrayList<>();
        for (StoragePlace place : places.findFreePlaces(chamberId)) {
            result.add(placeMapper.view(place));
        }
        return result;
    }

    @Transactional
    public StoredBoxView changePlace(AuthPrincipal principal, Long boxId, Long placeId) {
        access.requireRole(principal, RoleCode.CURATOR);
        Box box = lockBox(boxId);
        requireAwaiting(box);
        IntakeSession session = sessionFor(box.getBatch());
        if (session.getStatus() == SessionStatus.PLANNED) {
            requireInspection(session);
        } else if (session.getStatus() != SessionStatus.COMPLETED) {
            throw conflict("Сессия приёма отменена");
        }
        StoragePlace target = lockFreePlace(placeId, boxId);
        if (session.getStatus() == SessionStatus.PLANNED
                && !target.getChamber().getId().equals(session.getChamber().getId())) {
            throw conflict("При приёме место должно находиться в камере сессии");
        }
        box.setStoragePlace(target);
        return boxView(box, true);
    }

    @Transactional
    public StoredBoxView place(AuthPrincipal principal, Long boxId) {
        access.requireRole(principal, RoleCode.CURATOR);
        Box box = lockBox(boxId);
        requireAwaiting(box);
        IntakeSession session = sessionFor(box.getBatch());
        if (session.getStatus() == SessionStatus.PLANNED) {
            requireInspection(session);
        } else if (session.getStatus() != SessionStatus.COMPLETED) {
            throw conflict("Сессия приёма отменена");
        }
        if (box.getStoragePlace() == null) {
            throw conflict("Коробке не назначено место");
        }
        lockFreePlace(box.getStoragePlace().getId(), boxId);
        box.setStatus(BoxStatus.PLACED);
        box.setPlacedAt(OffsetDateTime.now());
        finishIntake(session);
        return boxView(box, true);
    }

    @Transactional
    public StoredBoxView writeOff(AuthPrincipal principal, Long boxId, String reason) {
        access.requireRole(principal, RoleCode.CURATOR);
        Box box = lockBox(boxId);
        requireAwaiting(box);
        IntakeSession session = sessionFor(box.getBatch());
        requireInspection(session);
        box.setStatus(BoxStatus.WRITTEN_OFF);
        box.setWriteOffReason(reason.strip());
        box.setWrittenOffAt(OffsetDateTime.now());
        box.setStoragePlace(null);
        finishIntake(session);
        return boxView(box, true);
    }

    @Transactional
    public StoredBoxView move(AuthPrincipal principal, Long boxId, Long placeId) {
        access.requireRole(principal, RoleCode.CURATOR);
        Box box = lockBox(boxId);
        if (box.getStatus() != BoxStatus.PLACED) {
            throw conflict("Перемещать можно только размещённую коробку");
        }
        if (sessionFor(box.getBatch()).getStatus() != SessionStatus.COMPLETED) {
            throw conflict("Сначала завершите приём всей партии");
        }
        if (box.getStoragePlace().getId().equals(placeId)) {
            throw conflict("Для перемещения выберите другое место");
        }
        StoragePlace target = lockFreePlace(placeId, boxId);
        box.setStoragePlace(target);
        box.setStatus(BoxStatus.AWAITING_PLACEMENT);
        box.setPlacedAt(null);
        return boxView(box, true);
    }

    public List<StoredBoxView> ownBoxes(AuthPrincipal principal, Long batchId) {
        batchAccess.owned(principal, batchId);
        List<StoredBoxView> result = new ArrayList<>();
        for (Box box : boxes.findAllByBatch_IdOrderBySeqNoAsc(batchId)) {
            result.add(boxView(box, false));
        }
        return result;
    }

    private void finishIntake(IntakeSession session) {
        // При перемещении после приёма его исторический итог не пересчитывается.
        if (session.getStatus() != SessionStatus.PLANNED) {
            return;
        }
        int placed = 0;
        List<Box> batchBoxes = boxes.findAllByBatch_IdOrderBySeqNoAsc(session.getBatch().getId());
        for (Box box : batchBoxes) {
            if (box.getStatus() == BoxStatus.PLACED) {
                placed++;
            } else if (box.getStatus() != BoxStatus.WRITTEN_OFF) {
                return;
            }
        }
        BatchStatus result;
        if (placed == batchBoxes.size()) {
            result = BatchStatus.PLACED;
        } else if (placed == 0) {
            result = BatchStatus.WRITTEN_OFF;
        } else {
            result = BatchStatus.PARTIALLY_PLACED;
        }
        session.getBatch().setStatus(result);
        session.setStatus(SessionStatus.COMPLETED);
        session.setCompletedAt(OffsetDateTime.now());
    }

    private Box lockBox(Long boxId) {
        // Сначала читаем только ID партии: сущность коробки загружаем уже после блокировки.
        Long batchId = boxes.findBatchIdById(boxId).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Коробка не найдена"));
        batchAccess.lock(batchId);
        return boxes.findById(boxId).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Коробка не найдена"));
    }

    private Chamber lockActiveChamber(Long chamberId) {
        Chamber chamber = chambers.findByIdForUpdate(chamberId).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Камера не найдена"));
        // Камера могла уже попасть в контекст JPA через место коробки до ожидания блокировки.
        entityManager.refresh(chamber, LockModeType.PESSIMISTIC_WRITE);
        if (chamber.getStatus() != ChamberStatus.ACTIVE) {
            throw conflict("Камера неактивна");
        }
        return chamber;
    }

    private StoragePlace lockFreePlace(Long placeId, Long boxId) {
        // Порядок блокировок одинаков: партия -> камера назначения -> место.
        Long chamberId = places.findById(placeId).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Место не найдено")).getChamber().getId();
        lockActiveChamber(chamberId);
        StoragePlace place = places.findByIdForUpdate(placeId).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Место не найдено"));
        entityManager.refresh(place, LockModeType.PESSIMISTIC_WRITE);
        if (!place.isServiceable()) {
            throw conflict("Место неисправно");
        }
        if (boxes.existsByStoragePlace_IdAndIdNot(placeId, boxId)) {
            throw conflict("Место уже занято или зарезервировано другой коробкой");
        }
        return place;
    }

    private IntakeSession sessionFor(Batch batch) {
        return sessions.findByBatch_Id(batch.getId()).orElseThrow(() -> conflict("У партии нет сессии приёма"));
    }

    private void requireInspection(IntakeSession session) {
        if (session.getStatus() != SessionStatus.PLANNED || session.getBatch().getStatus() != BatchStatus.INSPECTION) {
            throw conflict("Операция доступна только во время незавершённого приёма");
        }
        if (session.getPlannedDate().isAfter(LocalDate.now())) {
            throw conflict("Дата сессии приёма ещё не наступила");
        }
    }

    private void requireAwaiting(Box box) {
        if (box.getStatus() != BoxStatus.AWAITING_PLACEMENT) {
            throw conflict("Коробка должна ожидать размещения");
        }
    }

    private IntakeSessionView sessionView(IntakeSession session) {
        List<StoredBoxView> contents = new ArrayList<>();
        for (Box box : boxes.findAllByBatch_IdOrderBySeqNoAsc(session.getBatch().getId())) {
            contents.add(boxView(box, true));
        }
        return new IntakeSessionView(session.getId(), session.getBatch().getId(), session.getBatch().getStatus(),
                session.getCurator().getId(), session.getChamber().getId(), session.getPlannedDate(),
                session.getStatus(), session.getCompletedAt(), contents);
    }

    private StoredBoxView boxView(Box box, boolean curator) {
        StoragePlaceView location = null;
        if (box.getStoragePlace() != null && (curator || box.getStatus() == BoxStatus.PLACED)) {
            location = placeMapper.view(box.getStoragePlace());
        }
        return new StoredBoxView(box.getId(), box.getSeqNo(), box.getBarcode(), box.getStatus(),
                box.getWriteOffReason(), box.getPlacedAt(), location);
    }

    private ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }
}

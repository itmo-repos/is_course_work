package ru.ifmo.is.backend.services;

import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.batch.BatchData;
import ru.ifmo.is.backend.dto.batch.BatchView;
import ru.ifmo.is.backend.dto.batch.BoxData;
import ru.ifmo.is.backend.dto.batch.BoxView;
import ru.ifmo.is.backend.dto.batch.SampleData;
import ru.ifmo.is.backend.dto.batch.SampleView;
import ru.ifmo.is.backend.entitiy.*;
import ru.ifmo.is.backend.entitiy.enums.*;
import ru.ifmo.is.backend.repository.*;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BatchService {
    private final BatchRepository batches;
    private final BoxRepository boxes;
    private final SampleRepository samples;
    private final DepositorRepository depositors;
    private final SpeciesRepository species;
    private final CountryRepository countries;
    private final AccessService access;
    private final EntityManager entityManager;
    private final BarcodeService barcodeService;

    @Transactional
    public BatchView create(AuthPrincipal principal, BatchData data) {
        Depositor depositor = activeDepositor(principal);
        Batch batch = new Batch();
        batch.setDepositor(depositor);
        batch.setNumber(String.format(Locale.ROOT, "B-%06d", batches.nextNumber()));
        batch.setDesiredShipmentDate(data.desiredShipmentDate());
        batches.save(batch);
        saveContents(batch, data);
        return view(batch);
    }

    public List<BatchView> ownBatches(AuthPrincipal principal) {
        access.requireDepositor(principal);
        return batches.findAllByDepositor_IdOrderByFormedAtDesc(principal.id()).stream().map(this::view).toList();
    }

    public BatchView ownBatch(AuthPrincipal principal, Long id) {
        return view(ownedBatch(principal, id));
    }

    public List<BatchView> curatorBatches(AuthPrincipal principal, BatchStatus status) {
        access.requireRole(principal, RoleCode.CURATOR);
        return (status == null ? batches.findAllByOrderByFormedAtAsc()
                : batches.findAllByStatusOrderByFormedAtAsc(status)).stream().map(this::view).toList();
    }

    public BatchView curatorBatch(AuthPrincipal principal, Long id) {
        access.requireRole(principal, RoleCode.CURATOR);
        return view(findBatch(id));
    }

    @Transactional
    public BatchView confirm(AuthPrincipal principal, Long id) {
        Employee curator = access.requireEmployee(principal, RoleCode.CURATOR);
        Batch batch = lockBatch(id);
        requireStatus(batch, BatchStatus.FORMED);
        if (batch.getDepositor().getStatus() != DepositorStatus.ACTIVE) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Депозитор больше не активен");
        }
        batch.setStatus(BatchStatus.CONFIRMED);
        batch.setConfirmedBy(curator);
        batch.setConfirmedAt(OffsetDateTime.now());
        // UPDATE запускает SQL-триггер, заполняющий barcode коробок.
        batches.flush();
        entityManager.clear();
        return view(findBatch(id));
    }

    @Transactional
    public BatchView reject(AuthPrincipal principal, Long id, String reason) {
        access.requireRole(principal, RoleCode.CURATOR);
        Batch batch = lockBatch(id);
        requireStatus(batch, BatchStatus.FORMED);
        batch.setStatus(BatchStatus.REJECTED);
        batch.setRejectionReason(reason.strip());
        return view(batch);
    }

    @Transactional
    public BatchView resubmit(AuthPrincipal principal, Long id, BatchData data) {
        activeDepositor(principal);
        Batch batch = lockBatch(id);
        checkOwner(principal, batch);
        requireStatus(batch, BatchStatus.REJECTED);
        for (Box box : boxes.findAllByBatch_IdOrderBySeqNoAsc(id)) {
            samples.deleteAll(samples.findAllByBox_IdOrderByIdAsc(box.getId()));
            boxes.delete(box);
        }
        boxes.flush();
        batch.setDesiredShipmentDate(data.desiredShipmentDate());
        batch.setRejectionReason(null);
        batch.setStatus(BatchStatus.FORMED);
        saveContents(batch, data);
        return view(batch);
    }

    @Transactional
    public BatchView tracking(AuthPrincipal principal, Long id, BatchStatus status, String trackingNumber) {
        access.requireRole(principal, RoleCode.CURATOR);
        Batch batch = lockBatch(id);
        if (status == BatchStatus.IN_TRANSIT) {
            requireStatus(batch, BatchStatus.CONFIRMED);
        } else if (status == BatchStatus.ARRIVED) {
            requireStatus(batch, BatchStatus.IN_TRANSIT);
            batch.setArrivedAt(OffsetDateTime.now());
        } else {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Допустимы IN_TRANSIT и ARRIVED");
        }
        batch.setStatus(status);
        if (trackingNumber != null) {
            batch.setTrackingNumber(trackingNumber.isBlank() ? null : trackingNumber.strip());
        }
        return view(batch);
    }

    public String barcode(AuthPrincipal principal, Long batchId, Long boxId) {
        Batch batch = ownedBatch(principal, batchId);
        Box box = boxes.findById(boxId).filter(b -> b.getBatch().getId().equals(batch.getId()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Коробка не найдена"));
        if (box.getBarcode() == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Партия ещё не подтверждена");
        }
        return barcodeService.render(box.getBarcode());
    }

    private void saveContents(Batch batch, BatchData data) {
        short seq = 0;
        for (BoxData boxData : data.boxes()) {
            Box box = new Box();
            box.setBatch(batch);
            box.setSeqNo(++seq);
            boxes.save(box);
            for (SampleData passport : boxData.samples()) {
                if (passport.collectionYear() > LocalDate.now().getYear()) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Год сбора не может быть в будущем");
                }
                Sample sample = new Sample();
                sample.setBox(box);
                sample.setSpecies(species.findById(passport.speciesId()).orElseThrow(() ->
                        new ResponseStatusException(HttpStatus.BAD_REQUEST, "Неизвестный вид")));
                sample.setOriginCountry(countries.findById(passport.originCountryCode().toUpperCase(Locale.ROOT))
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Неизвестная страна")));
                sample.setCollectionYear(passport.collectionYear().shortValue());
                sample.setSeedQuantity(passport.seedQuantity());
                sample.setAccessionCode(String.format(Locale.ROOT, "S-%06d", samples.nextAccessionNumber()));
                sample.setNote(passport.note());
                samples.save(sample);
            }
        }
    }

    private BatchView view(Batch batch) {
        List<BoxView> boxViews = new ArrayList<>();
        List<Box> batchBoxes = boxes.findAllByBatch_IdOrderBySeqNoAsc(batch.getId());

        for (Box box : batchBoxes) {
            List<SampleView> sampleViews = new ArrayList<>();
            List<Sample> boxSamples = samples.findAllByBox_IdOrderByIdAsc(box.getId());

            for (Sample sample : boxSamples) {
                SampleView sampleView = new SampleView(
                        sample.getId(),
                        sample.getAccessionCode(),
                        sample.getSpecies().getId(),
                        sample.getSpecies().getLatinName(),
                        sample.getOriginCountry().getCode(),
                        sample.getCollectionYear(),
                        sample.getSeedQuantity(),
                        sample.getNote());
                sampleViews.add(sampleView);
            }

            BoxView boxView = new BoxView(
                    box.getId(),
                    box.getSeqNo(),
                    box.getStatus(),
                    box.getBarcode(),
                    sampleViews);
            boxViews.add(boxView);
        }

        return new BatchView(
                batch.getId(),
                batch.getNumber(),
                batch.getDepositor().getId(),
                batch.getStatus(),
                batch.getDesiredShipmentDate(),
                batch.getFormedAt(),
                batch.getConfirmedAt(),
                batch.getArrivedAt(),
                batch.getTrackingNumber(),
                batch.getRejectionReason(),
                boxViews.size(),
                boxViews);
    }

    private Depositor activeDepositor(AuthPrincipal principal) {
        access.requireDepositor(principal);
        Depositor depositor = depositors.findByIdForUpdate(principal.id()).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Депозитор не найден"));
        if (depositor.getStatus() != DepositorStatus.ACTIVE) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Для формирования партии нужен активный договор");
        }
        return depositor;
    }

    private Batch ownedBatch(AuthPrincipal principal, Long id) {
        access.requireDepositor(principal);
        Batch batch = findBatch(id);
        checkOwner(principal, batch);
        return batch;
    }

    private void checkOwner(AuthPrincipal principal, Batch batch) {
        if (!batch.getDepositor().getId().equals(principal.id())) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Партия не найдена");
        }
    }

    private Batch findBatch(Long id) {
        return batches.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Партия не найдена"));
    }

    private Batch lockBatch(Long id) {
        return batches.findByIdForUpdate(id).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Партия не найдена"));
    }

    private void requireStatus(Batch batch, BatchStatus status) {
        if (batch.getStatus() != status) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Ожидался статус " + status + ", текущий: " + batch.getStatus());
        }
    }
}

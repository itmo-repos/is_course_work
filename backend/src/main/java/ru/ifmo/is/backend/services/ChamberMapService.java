package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.entitiy.Chamber;
import ru.ifmo.is.backend.entitiy.enums.BatchStatus;
import ru.ifmo.is.backend.entitiy.enums.BoxStatus;
import ru.ifmo.is.backend.entitiy.enums.ChamberStatus;
import ru.ifmo.is.backend.repository.ChamberRepository;
import ru.ifmo.is.backend.repository.EmployeeRepository;
import ru.ifmo.is.backend.repository.StoragePlaceRepository;
import ru.ifmo.is.backend.repository.projections.StoragePlaceMapProjection;
import ru.ifmo.is.backend.security.AuthPrincipal;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
public class ChamberMapService {
    private final ChamberRepository chambers;
    private final StoragePlaceRepository places;
    private final EmployeeRepository employees;

    public ChamberMapView getMap(AuthPrincipal principal, Long chamberId) {
        if (principal == null || principal.type() != AuthPrincipal.AccountType.EMPLOYEE
                || !employees.hasRole(principal.id(), "CURATOR")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Доступ только куратору");
        }
        Chamber chamber = chambers.findById(chamberId).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Камера не найдена"));
        List<MapPlaceView> result = new ArrayList<>();
        int free = 0;
        int reserved = 0;
        int occupied = 0;
        int unserviceable = 0;
        int available = 0;

        // Все места и назначения читаются одним запросом; сводка считается из тех же строк.
        for (StoragePlaceMapProjection place : places.findChamberMap(chamberId)) {
            Occupancy occupancy = Occupancy.FREE;
            AssignedBoxView assignedBox = null;
            if (place.getBoxId() != null) {
                BoxStatus status = BoxStatus.valueOf(place.getBoxStatus());
                occupancy = status == BoxStatus.PLACED ? Occupancy.OCCUPIED : Occupancy.RESERVED;
                assignedBox = new AssignedBoxView(
                        place.getBoxId(), place.getBoxSeqNo(), place.getBarcode(), status,
                        place.getBatchId(), place.getBatchNumber(), BatchStatus.valueOf(place.getBatchStatus()),
                        place.getDepositorId(), place.getDepositorName());
            }
            boolean serviceable = place.getServiceable();
            boolean canAssign = chamber.getStatus() == ChamberStatus.ACTIVE && serviceable
                    && occupancy == Occupancy.FREE;
            switch (occupancy) {
                case FREE -> free++;
                case RESERVED -> reserved++;
                case OCCUPIED -> occupied++;
            }
            if (!serviceable) unserviceable++;
            if (canAssign) available++;
            result.add(new MapPlaceView(place.getId(), place.getRackNo(), place.getShelfNo(), place.getRowNo(),
                    serviceable, occupancy, canAssign, assignedBox));
        }
        MapSummary summary = new MapSummary(result.size(), free, reserved, occupied, unserviceable, available);
        return new ChamberMapView(chamber.getId(), chamber.getCode(), chamber.getName(), chamber.getStatus(), summary, result);
    }

    public enum Occupancy { FREE, RESERVED, OCCUPIED }
    public record MapSummary(int total, int free, int reserved, int occupied, int unserviceable, int available) {}
    public record AssignedBoxView(Long id, short seqNo, String barcode, BoxStatus status,
                                  Long batchId, String batchNumber, BatchStatus batchStatus,
                                  Long depositorId, String depositorName) {}
    public record MapPlaceView(Long id, short rackNo, short shelfNo, short rowNo, boolean serviceable,
                               Occupancy occupancy, boolean available, AssignedBoxView box) {}
    public record ChamberMapView(Long chamberId, String code, String name, ChamberStatus status,
                                 MapSummary summary, List<MapPlaceView> places) {}
}

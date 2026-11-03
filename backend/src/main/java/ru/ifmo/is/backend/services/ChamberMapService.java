package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.storage.AssignedBoxView;
import ru.ifmo.is.backend.dto.storage.ChamberMapSummary;
import ru.ifmo.is.backend.dto.storage.ChamberMapView;
import ru.ifmo.is.backend.dto.storage.Occupancy;
import ru.ifmo.is.backend.dto.storage.StoragePlaceMapView;
import ru.ifmo.is.backend.entitiy.Chamber;
import ru.ifmo.is.backend.entitiy.enums.BatchStatus;
import ru.ifmo.is.backend.entitiy.enums.BoxStatus;
import ru.ifmo.is.backend.entitiy.enums.ChamberStatus;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;
import ru.ifmo.is.backend.repository.ChamberRepository;
import ru.ifmo.is.backend.repository.StoragePlaceRepository;
import ru.ifmo.is.backend.repository.projections.StoragePlaceMapProjection;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
public class ChamberMapService {
    private final ChamberRepository chambers;
    private final StoragePlaceRepository places;
    private final AccessService access;

    public ChamberMapView getMap(AuthPrincipal principal, Long chamberId) {
        access.requireRole(principal, RoleCode.CURATOR);
        Chamber chamber = chambers.findById(chamberId).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Камера не найдена"));
        List<StoragePlaceMapView> result = new ArrayList<>();
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
            result.add(new StoragePlaceMapView(place.getId(), place.getRackNo(), place.getShelfNo(), place.getRowNo(),
                    serviceable, occupancy, canAssign, assignedBox));
        }
        ChamberMapSummary summary = new ChamberMapSummary(result.size(), free, reserved, occupied, unserviceable, available);
        return new ChamberMapView(chamber.getId(), chamber.getCode(), chamber.getName(), chamber.getStatus(), summary, result);
    }
}

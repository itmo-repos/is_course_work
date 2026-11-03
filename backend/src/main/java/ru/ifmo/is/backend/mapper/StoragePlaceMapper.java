package ru.ifmo.is.backend.mapper;

import org.springframework.stereotype.Component;
import ru.ifmo.is.backend.dto.storage.StoragePlaceView;
import ru.ifmo.is.backend.entitiy.StoragePlace;

@Component
public class StoragePlaceMapper {
    public StoragePlaceView view(StoragePlace place) {
        return new StoragePlaceView(place.getId(), place.getChamber().getId(), place.getChamber().getCode(),
                place.getRackNo(), place.getShelfNo(), place.getRowNo());
    }
}

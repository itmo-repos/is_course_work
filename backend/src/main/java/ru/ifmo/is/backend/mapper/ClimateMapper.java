package ru.ifmo.is.backend.mapper;

import org.springframework.stereotype.Component;
import ru.ifmo.is.backend.dto.climate.ChamberClimateView;
import ru.ifmo.is.backend.dto.climate.ClimateReadingView;
import ru.ifmo.is.backend.entitiy.Chamber;
import ru.ifmo.is.backend.entitiy.ClimateReading;
import java.time.ZoneOffset;

@Component
public class ClimateMapper {
    public ClimateReadingView reading(ClimateReading reading) {
        return new ClimateReadingView(reading.getId(), reading.getChamber().getId(),
                reading.getMeasuredAt().atOffset(ZoneOffset.UTC), reading.getTemperature(), reading.getHumidity());
    }

    public ChamberClimateView chamber(Chamber chamber, ClimateReading latest) {
        return new ChamberClimateView(chamber.getId(), chamber.getCode(), chamber.getName(), chamber.getStatus(),
                chamber.isClimateControlled(), chamber.getMinTemperature(), chamber.getMaxTemperature(),
                chamber.getMinHumidity(), chamber.getMaxHumidity(), latest == null ? null : reading(latest));
    }
}

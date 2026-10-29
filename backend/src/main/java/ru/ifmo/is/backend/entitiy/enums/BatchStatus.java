package ru.ifmo.is.backend.entitiy.enums;

public enum BatchStatus {
    FORMED,             // сформирована
    CONFIRMED,          // подтверждена курирующим сотрудником
    REJECTED,           // отклонена курирующим сотрудником (ALT2 прецедента 3)
    IN_TRANSIT,         // в пути
    ARRIVED,            // прибыла
    INSPECTION,         // на досмотре
    PLACED,             // размещена
    PARTIALLY_PLACED,   // размещена частично
    WRITTEN_OFF         // списана
}

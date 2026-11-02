package ru.ifmo.is.backend.repository.projections;

public interface StoragePlaceMapProjection {
    Long getId();
    Short getRackNo();
    Short getShelfNo();
    Short getRowNo();
    Boolean getServiceable();
    Long getBoxId();
    Short getBoxSeqNo();
    String getBarcode();
    String getBoxStatus();
    Long getBatchId();
    String getBatchNumber();
    String getBatchStatus();
    Long getDepositorId();
    String getDepositorName();
}

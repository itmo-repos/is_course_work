package ru.ifmo.is.backend.repository.projections;

// результат поиска партии по штрихкоду коробки
public interface BatchBarcodeProjection {
    // todo тут пока хз какие методы оставить
    Long getBatchId();

    String getBatchNumber();

    String getDepositorName();

    String getCurrentStatus();

    Long getBoxCount();
}

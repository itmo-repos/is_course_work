package ru.ifmo.is.backend.repository.projections;

// результат публичного поиска образцов семян
public interface SampleSearchProjection {
    String getAccessionCode();

    String getLatinName();

    String getLocalName();

    String getOriginCountry();

    Short getCollectionYear();

    Integer getSeedQuantity();

    String getDepositorName();
}

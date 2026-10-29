package ru.ifmo.is.backend.repository.projections;

// результат публичного поиска образцов семян
public interface SampleSearchProjection {
    // todo тут пока хз какие методы оставить
    String getAccessionCode();

    String getLatinName();

    String getLocalName();

    String getOriginCountry();

    Short getCollectionYear();

    Integer getSeedQuantity();

    String getDepositorName();
}

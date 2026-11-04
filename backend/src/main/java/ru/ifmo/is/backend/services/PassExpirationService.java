package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ru.ifmo.is.backend.repository.VaultPassRepository;
import java.time.LocalDateTime;
import java.time.ZoneOffset;

@Service
@RequiredArgsConstructor
public class PassExpirationService {
    private final VaultPassRepository passes;

    @Scheduled(fixedDelay = 60000)
    @Transactional
    public void expire() {
        passes.expire(LocalDateTime.now(ZoneOffset.UTC));
    }
}

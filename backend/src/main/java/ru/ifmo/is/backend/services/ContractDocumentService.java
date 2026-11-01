package ru.ifmo.is.backend.services;

import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;

@Service
public class ContractDocumentService {
    public byte[] readTemplate() {
        try {
            return Files.readAllBytes(Path.of("contract.pdf"));
        } catch (NoSuchFileException ignored) {
            // Если внешнего файла нет, используем шаблон из сборки.
        } catch (IOException exception) {
            throw new IllegalStateException("Не удалось прочитать внешний шаблон договора", exception);
        }
        try (var input = new ClassPathResource("templates/contract.pdf").getInputStream()) {
            return input.readAllBytes();
        } catch (IOException exception) {
            throw new IllegalStateException("Не удалось прочитать шаблон договора", exception);
        }
    }
}

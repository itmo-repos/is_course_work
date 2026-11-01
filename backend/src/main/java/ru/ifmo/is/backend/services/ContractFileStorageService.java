package ru.ifmo.is.backend.services;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.attribute.PosixFilePermission;
import java.util.Set;

@Service
public class ContractFileStorageService {
    private final Path root;

    public ContractFileStorageService(@Value("${app.contract.storage-dir}") String storageDir) {
        this.root = Path.of(storageDir).toAbsolutePath().normalize();
    }

    public String store(String relativePath, byte[] content) {
        Path target = resolve(relativePath);
        try {
            Files.createDirectories(target.getParent());
            setPermissions(root, Set.of(PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_WRITE,
                    PosixFilePermission.OWNER_EXECUTE));
            setPermissions(target.getParent(), Set.of(PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_WRITE,
                    PosixFilePermission.OWNER_EXECUTE));
            Path temporary = Files.createTempFile(target.getParent(), ".contract-", ".tmp");
            try {
                Files.write(temporary, content);
                try {
                    Files.move(temporary, target, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
                } catch (AtomicMoveNotSupportedException ignored) {
                    Files.move(temporary, target, StandardCopyOption.REPLACE_EXISTING);
                }
                setPermissions(target, Set.of(PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_WRITE));
            } finally {
                Files.deleteIfExists(temporary);
            }
            return relativePath;
        } catch (IOException exception) {
            throw new IllegalStateException("Не удалось сохранить файл договора", exception);
        }
    }

    public byte[] read(String relativePath) {
        try {
            return Files.readAllBytes(resolve(relativePath));
        } catch (java.nio.file.NoSuchFileException exception) {
            throw new org.springframework.web.server.ResponseStatusException(
                    org.springframework.http.HttpStatus.NOT_FOUND, "Файл договора не найден", exception);
        } catch (IOException exception) {
            throw new IllegalStateException("Файл договора не найден в хранилище", exception);
        }
    }

    public void delete(String relativePath) {
        if (relativePath == null || relativePath.isBlank()) return;
        try {
            Files.deleteIfExists(resolve(relativePath));
        } catch (IOException exception) {
            throw new IllegalStateException("Не удалось удалить файл договора", exception);
        }
    }

    private Path resolve(String relativePath) {
        Path path = root.resolve(relativePath).normalize();
        if (!path.startsWith(root)) {
            throw new IllegalArgumentException("Invalid stored contract path");
        }
        return path;
    }

    private static void setPermissions(Path path, Set<PosixFilePermission> permissions) throws IOException {
        try {
            Files.setPosixFilePermissions(path, permissions);
        } catch (UnsupportedOperationException ignored) {
            // On non-POSIX development systems, retain the platform's default file permissions.
        }
    }
}

package ru.ifmo.is.backend.security;

public class TestPasswordHash {
    public static void main(String[] args) {
        String pepper = System.getenv("APP_AUTH_PEPPER");

        if (pepper == null || pepper.isBlank()) {
            throw new IllegalStateException(
                    "Укажите APP_AUTH_PEPPER в конфигурации запуска"
            );
        }

        var encoder = new PasswordConfig().passwordEncoder(pepper);
        String hash = encoder.encode("Demo123!");

        if (!encoder.matches("Demo123!", hash)) {
            throw new IllegalStateException("Проверка хеша не прошла");
        }

        System.out.println(hash);
    }
}
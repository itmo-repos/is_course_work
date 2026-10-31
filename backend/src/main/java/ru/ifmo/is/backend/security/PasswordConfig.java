package ru.ifmo.is.backend.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

@Configuration
public class PasswordConfig {
    @Bean
    PasswordEncoder passwordEncoder(@Value("${app.auth.pepper}") String pepper) {
        byte[] pepperKey = Base64.getDecoder().decode(pepper);
        if (pepperKey.length < 32) {
            throw new IllegalStateException("APP_AUTH_PEPPER must be a base64-encoded key of at least 32 bytes");
        }

        Argon2PasswordEncoder argon2 = new Argon2PasswordEncoder(16, 32, 1, 19 * 1024, 2);
        return new PasswordEncoder() {
            @Override
            public String encode(CharSequence rawPassword) {
                return argon2.encode(prehash(rawPassword, pepperKey));
            }

            @Override
            public boolean matches(CharSequence rawPassword, String encodedPassword) {
                if (encodedPassword == null || !encodedPassword.startsWith("$argon2id$")) {
                    return false;
                }
                return argon2.matches(prehash(rawPassword, pepperKey), encodedPassword);
            }

            private String prehash(CharSequence password, byte[] key) {
                try {
                    Mac mac = Mac.getInstance("HmacSHA256");
                    mac.init(new SecretKeySpec(key, "HmacSHA256"));
                    byte[] digest = mac.doFinal(password.toString().getBytes(StandardCharsets.UTF_8));
                    return Base64.getEncoder().encodeToString(digest);
                } catch (Exception e) {
                    throw new IllegalStateException("Unable to process password", e);
                }
            }
        };
    }
}

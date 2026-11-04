package ru.ifmo.is.backend.dto.pass;

public record IssuedPass(PassView pass, String code, String qrSvg) {}

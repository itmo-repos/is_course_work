package ru.ifmo.is.backend.services;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;

public class ReportCsv {
    private final StringBuilder text = new StringBuilder("\uFEFF");

    public ReportCsv(String... headers) {
        row((Object[]) headers);
    }

    public void row(Object... values) {
        for (int i = 0; i < values.length; i++) {
            if (i > 0) text.append(',');
            Object value = values[i];
            String cell = value == null ? "" : value instanceof BigDecimal number
                    ? number.toPlainString() : value.toString();
            // Строки из БД не должны превращаться в формулы при открытии в Excel.
            if (value instanceof String && isFormula(cell)) cell = "'" + cell;
            text.append('"').append(cell.replace("\"", "\"\"")).append('"');
        }
        text.append("\r\n");
    }

    private boolean isFormula(String value) {
        String trimmed = value.stripLeading();
        return (!trimmed.isEmpty() && "=+-@＝＋－＠".indexOf(trimmed.charAt(0)) >= 0)
                || (!value.isEmpty() && "\t\r\n".indexOf(value.charAt(0)) >= 0);
    }

    public byte[] bytes() {
        return text.toString().getBytes(StandardCharsets.UTF_8);
    }
}

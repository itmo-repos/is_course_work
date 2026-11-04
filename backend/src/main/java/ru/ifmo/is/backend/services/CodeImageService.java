package ru.ifmo.is.backend.services;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.oned.Code128Writer;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;
import org.springframework.stereotype.Service;
import java.util.Map;

@Service
public class CodeImageService {
    public String renderQr(String code) {
        BitMatrix matrix;
        try {
            matrix = new QRCodeWriter().encode(code, BarcodeFormat.QR_CODE, 0, 0,
                    Map.of(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.M));
        } catch (WriterException exception) {
            throw new IllegalStateException("Не удалось создать QR пропуска", exception);
        }
        int size = matrix.getWidth();
        StringBuilder svg = new StringBuilder("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"")
                .append(size * 8).append("\" height=\"").append(size * 8)
                .append("\" viewBox=\"0 0 ").append(size).append(' ').append(size)
                .append("\" shape-rendering=\"crispEdges\"><rect width=\"100%\" height=\"100%\" fill=\"white\"/><g fill=\"black\">");
        for (int y = 0; y < size; y++) {
            for (int x = 0; x < size; x++) {
                if (matrix.get(x, y)) {
                    svg.append("<rect x=\"").append(x).append("\" y=\"").append(y)
                            .append("\" width=\"1\" height=\"1\"/>");
                }
            }
        }
        return svg.append("</g></svg>").toString();
    }

    public String renderBarcode(String barcode) {
        BitMatrix matrix = new Code128Writer().encode(barcode, BarcodeFormat.CODE_128, 640, 120);
        StringBuilder svg = new StringBuilder("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""
                + matrix.getWidth() + "\" height=\"150\" viewBox=\"0 0 " + matrix.getWidth()
                + " 150\"><rect width=\"100%\" height=\"100%\" fill=\"white\"/><g fill=\"black\">");
        for (int x = 0; x < matrix.getWidth(); x++) {
            if (matrix.get(x, 0)) {
                svg.append("<rect x=\"").append(x).append("\" y=\"0\" width=\"1\" height=\"120\"/>");
            }
        }
        return svg.append("</g><text x=\"50%\" y=\"140\" text-anchor=\"middle\" font-family=\"monospace\" font-size=\"14\">")
                .append(barcode).append("</text></svg>").toString();
    }
}

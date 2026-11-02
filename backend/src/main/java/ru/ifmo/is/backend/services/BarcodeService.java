package ru.ifmo.is.backend.services;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.oned.Code128Writer;
import org.springframework.stereotype.Service;

@Service
public class BarcodeService {
    public String render(String barcode) {
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

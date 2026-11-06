package com.orleu.payments;

import org.springframework.http.CacheControl;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}/finance")
public class LedgerExportController {
    private final LedgerExportService export;

    public LedgerExportController(LedgerExportService export) { this.export = export; }

    /** CSV of ledger entries in [from, to). delimiter=semicolon for Excel in Russian/Kazakh locales. */
    @GetMapping("/export")
    public ResponseEntity<byte[]> export(@PathVariable UUID businessId, @RequestParam Instant from, @RequestParam Instant to,
                                         @RequestParam(defaultValue = "comma") String delimiter) {
        var e = export.export(businessId, from, to, "semicolon".equals(delimiter));
        return ResponseEntity.ok()
                .contentType(new MediaType("text", "csv", StandardCharsets.UTF_8))
                .cacheControl(CacheControl.noStore())
                .header("X-Content-Type-Options", "nosniff")
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment().filename(e.fileName()).build().toString())
                .header("X-Export-Rows", String.valueOf(e.rows()))
                .body(e.bytes());
    }
}

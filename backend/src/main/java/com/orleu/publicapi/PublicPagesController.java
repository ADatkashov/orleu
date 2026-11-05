package com.orleu.publicapi;

import com.orleu.business.Business;
import com.orleu.business.BusinessRepository;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.HtmlUtils;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Optional;

/**
 * Server-rendered shells of the public pages. Only escaped business text goes into the HTML head
 * (SEO/OpenGraph); the interactive flow lives in static JS that talks to the public API.
 * A strict CSP (no inline script/style, same-origin only) is the second line of defence against XSS.
 */
@RestController
public class PublicPagesController {
    private static final String CSP = "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' data:; "
            + "base-uri 'none'; form-action 'none'; frame-ancestors 'none'";

    private final BusinessRepository businesses;
    private final String bookingTemplate = load("templates/booking.html");
    private final String manageTemplate = load("templates/manage.html");

    public PublicPagesController(BusinessRepository businesses) { this.businesses = businesses; }

    @GetMapping(value = "/b/{slug}", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> booking(@PathVariable String slug) {
        Optional<Business> b = businesses.findBySlug(slug).filter(x -> x.isPublished() && !"SUSPENDED".equals(x.getStatus()));
        if (b.isEmpty()) return page(HttpStatus.NOT_FOUND, notFound(), false);
        Business biz = b.get();
        String desc = biz.getDescription() == null || biz.getDescription().isBlank()
                ? biz.getName() + (biz.getCity() == null ? "" : " — " + biz.getCity())
                : biz.getDescription();
        if (desc.length() > 160) desc = desc.substring(0, 157) + "...";
        String html = bookingTemplate
                .replace("{{TITLE}}", esc(biz.getName() + " — ORLEU"))
                .replace("{{DESCRIPTION}}", esc(desc))
                .replace("{{SLUG}}", esc(biz.getSlug()));
        return page(HttpStatus.OK, html, false);
    }

    @GetMapping(value = "/m/{token}", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> manage(@PathVariable String token) {
        // The token is a credential: never cached, never leaked through Referer, never indexed.
        return page(HttpStatus.OK, manageTemplate.replace("{{TOKEN}}", esc(token)), true);
    }

    private ResponseEntity<String> page(HttpStatus status, String html, boolean sensitive) {
        var r = ResponseEntity.status(status).contentType(new MediaType("text", "html", StandardCharsets.UTF_8))
                .header("Content-Security-Policy", CSP)
                .header("X-Content-Type-Options", "nosniff")
                .header("Referrer-Policy", sensitive ? "no-referrer" : "strict-origin-when-cross-origin");
        if (sensitive) r.cacheControl(CacheControl.noStore());
        return r.body(html);
    }

    private static String notFound() {
        return "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"robots\" content=\"noindex\"><title>ORLEU</title></head>"
                + "<body style=\"font-family:system-ui;padding:2rem\"><h1>404</h1></body></html>";
    }

    private static String esc(String s) { return HtmlUtils.htmlEscape(s == null ? "" : s, "UTF-8"); }

    private static String load(String path) {
        try (var in = new ClassPathResource(path).getInputStream()) {
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) { throw new IllegalStateException(e); }
    }
}

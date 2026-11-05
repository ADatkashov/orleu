package com.orleu.common;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Fixed-window per-IP limiter for unauthenticated, abuse-prone endpoints (auth, public booking).
 * LIMITATION: in-memory, so the limit applies per application instance. A shared limiter (gateway/WAF
 * or a database-backed counter) is required before scaling to several replicas.
 */
@Component
public class RateLimitFilter extends OncePerRequestFilter {
    private record Window(long minute, int count) {}
    private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();
    private final int perMinute;

    public RateLimitFilter(@Value("${orleu.rate-limit.per-minute:60}") int perMinute) { this.perMinute = perMinute; }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        String p = req.getRequestURI();
        return !(p.startsWith("/api/v1/auth/") || (p.startsWith("/api/v1/public/") && !"GET".equals(req.getMethod())));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        long minute = System.currentTimeMillis() / 60_000;
        String key = req.getRemoteAddr() + (req.getRequestURI().startsWith("/api/v1/auth/") ? "|auth" : "|public");
        Window w = windows.merge(key, new Window(minute, 1), (old, n) -> old.minute() == minute ? new Window(minute, old.count() + 1) : n);
        if (windows.size() > 50_000) windows.entrySet().removeIf(e -> e.getValue().minute() < minute);
        if (w.count() > perMinute) {
            res.setStatus(429);
            res.setHeader("Retry-After", "60");
            res.setContentType("application/json");
            res.getWriter().write("{\"code\":\"RATE_LIMITED\",\"message\":\"Too many requests\"}");
            return;
        }
        chain.doFilter(req, res);
    }
}

package com.orleu.audit;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

import java.util.UUID;

/** Append-only audit trail for security- and money-relevant actions. */
@Service
public class AuditService {
    private final JdbcClient jdbc;

    public AuditService(JdbcClient jdbc) { this.jdbc = jdbc; }

    public void log(UUID businessId, UUID actorUserId, String action, String entityType, UUID entityId, String detailsJson) {
        jdbc.sql("""
                insert into audit_logs (business_id, actor_user_id, action, entity_type, entity_id, details)
                values (:b, :a, :act, :et, :eid, cast(:d as jsonb))
                """)
            .param("b", businessId).param("a", actorUserId).param("act", action)
            .param("et", entityType).param("eid", entityId).param("d", detailsJson)
            .update();
    }
}

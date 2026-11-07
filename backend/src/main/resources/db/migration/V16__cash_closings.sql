-- Cash register closing ("Z-report"): staff count the physical cash and the system records expected vs counted for the period
-- since the previous closing. Append-only like the ledger; a mistake is corrected by the next closing, never by editing.
CREATE TABLE cash_closings (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      uuid NOT NULL REFERENCES businesses(id),
    period_start     timestamptz NOT NULL,
    period_end       timestamptz NOT NULL,
    currency         varchar(3) NOT NULL,
    expected_cash    numeric(14,2) NOT NULL,   -- cash payments minus cash refunds in the period
    expected_bank    numeric(14,2) NOT NULL,   -- bank transfers, net (informational: not counted physically)
    expected_card    numeric(14,2) NOT NULL,   -- manual card payments, net (informational)
    counted_cash     numeric(14,2) NOT NULL CHECK (counted_cash >= 0),
    difference       numeric(14,2) NOT NULL,   -- counted - expected: negative = shortage, positive = surplus
    note             varchar(500),
    closed_by        uuid NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    CHECK (period_end > period_start),
    CHECK (difference = counted_cash - expected_cash)
);
CREATE INDEX cash_closings_business_idx ON cash_closings (business_id, period_end DESC);

CREATE FUNCTION cash_closings_immutable() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'cash_closings is append-only';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER cash_closings_no_update BEFORE UPDATE OR DELETE ON cash_closings FOR EACH ROW EXECUTE FUNCTION cash_closings_immutable();

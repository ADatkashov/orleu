-- Gift cards (prepaid stored value). Selling one is NOT revenue and not a booking payment: the cash received is a liability until the card is
-- redeemed against a booking, which writes a PAYMENT with method GIFT_CARD to the ledger. The code is shown once at sale and stored only as a hash.
ALTER TABLE ledger_entries DROP CONSTRAINT IF EXISTS ledger_entries_method_check;
ALTER TABLE ledger_entries ADD CONSTRAINT ledger_entries_method_check CHECK (method IN ('CASH','BANK_TRANSFER','CARD_MANUAL','GIFT_CARD'));

CREATE TABLE gift_cards (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      uuid NOT NULL REFERENCES businesses(id),
    code_hash        varchar(64) NOT NULL,
    code_last4       varchar(4) NOT NULL,
    initial_amount   numeric(14,2) NOT NULL CHECK (initial_amount > 0),
    balance          numeric(14,2) NOT NULL CHECK (balance >= 0),
    currency         varchar(3) NOT NULL,
    sold_method      varchar(20) NOT NULL CHECK (sold_method IN ('CASH','BANK_TRANSFER','CARD_MANUAL')),
    buyer_name       varchar(200),
    note             varchar(300),
    idempotency_key  varchar(100) NOT NULL,      -- a retried sale never creates a second card
    expires_on       date,                       -- business-local, inclusive; NULL = does not expire (legal review needed before choosing defaults)
    status           varchar(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','VOID')),
    voided_by        uuid,
    voided_at        timestamptz,
    created_by       uuid NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    CHECK (balance <= initial_amount),
    UNIQUE (business_id, code_hash),
    UNIQUE (business_id, idempotency_key),
    UNIQUE (id, business_id)
);
CREATE INDEX gift_cards_business_idx ON gift_cards (business_id, created_at DESC);

CREATE TABLE gift_card_redemptions (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      uuid NOT NULL,
    gift_card_id     uuid NOT NULL,
    booking_id       uuid NOT NULL,
    amount           numeric(14,2) NOT NULL CHECK (amount > 0),
    idempotency_key  varchar(100) NOT NULL,
    created_by       uuid NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (gift_card_id, business_id) REFERENCES gift_cards(id, business_id),
    FOREIGN KEY (booking_id, business_id) REFERENCES bookings(id, business_id),
    UNIQUE (business_id, idempotency_key)
);
CREATE INDEX gift_card_redemptions_card_idx ON gift_card_redemptions (gift_card_id, created_at);

CREATE FUNCTION gift_card_redemptions_immutable() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'gift_card_redemptions is append-only';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER gift_card_redemptions_no_change BEFORE UPDATE OR DELETE ON gift_card_redemptions FOR EACH ROW EXECUTE FUNCTION gift_card_redemptions_immutable();

-- Returning gift-card value to the card when a booking that was (partly) paid with it is cancelled or refunded.
-- Append-only like redemptions. Restorable per booking and card = redeemed on that booking - already restored.
CREATE TABLE gift_card_restorations (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      uuid NOT NULL,
    gift_card_id     uuid NOT NULL,
    booking_id       uuid NOT NULL,
    amount           numeric(14,2) NOT NULL CHECK (amount > 0),
    idempotency_key  varchar(100) NOT NULL,
    created_by       uuid NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (gift_card_id, business_id) REFERENCES gift_cards(id, business_id),
    FOREIGN KEY (booking_id, business_id) REFERENCES bookings(id, business_id)
);
CREATE INDEX gift_card_restorations_booking_idx ON gift_card_restorations (booking_id, gift_card_id);

CREATE FUNCTION gift_card_restorations_immutable() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'gift_card_restorations is append-only';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER gift_card_restorations_no_change BEFORE UPDATE OR DELETE ON gift_card_restorations FOR EACH ROW EXECUTE FUNCTION gift_card_restorations_immutable();

-- Discounts / promo codes. A booking stores the final (discounted) price plus the discount that was applied,
-- so deposits, payments and reports keep working on `price` unchanged.
CREATE TABLE promo_codes (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  uuid NOT NULL REFERENCES businesses(id),
    code         varchar(32) NOT NULL,                      -- stored upper-case
    kind         varchar(10) NOT NULL CHECK (kind IN ('PERCENT','FIXED')),
    value        numeric(14,2) NOT NULL CHECK (value > 0),  -- percent (0-100] or amount in business currency
    valid_from   date,
    valid_until  date,                                      -- inclusive, business-local date
    max_uses     integer CHECK (max_uses IS NULL OR max_uses > 0),
    used_count   integer NOT NULL DEFAULT 0 CHECK (used_count >= 0),
    service_id   uuid,                                      -- NULL = any service
    active       boolean NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CHECK (kind <> 'PERCENT' OR value <= 100),
    CHECK (max_uses IS NULL OR used_count <= max_uses),
    UNIQUE (business_id, code),
    UNIQUE (id, business_id),
    FOREIGN KEY (service_id, business_id) REFERENCES services(id, business_id)
);

ALTER TABLE bookings
    ADD COLUMN promo_code_id    uuid,
    ADD COLUMN discount_amount  numeric(14,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    ADD FOREIGN KEY (promo_code_id, business_id) REFERENCES promo_codes(id, business_id);

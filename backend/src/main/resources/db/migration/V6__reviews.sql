-- V6: customer reviews. One per booking, only for COMPLETED bookings (enforced in ReviewService), submitted via the booking's manage token.
CREATE TABLE reviews (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    booking_id  uuid NOT NULL,
    rating      smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     varchar(1000),
    created_at  timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (booking_id, business_id) REFERENCES bookings(id, business_id),
    UNIQUE (booking_id)
);
CREATE INDEX reviews_business_idx ON reviews (business_id, created_at DESC);

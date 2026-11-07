-- Business reply to a review (shown to the guest on their booking link) and platform moderation.
-- A business can never hide or delete a review; only platform support can hide one, with a recorded reason. Hidden reviews are excluded
-- from the average and from the guest-facing reply, but stay in the table (and visible to the business as "hidden by the platform").
ALTER TABLE reviews
    ADD COLUMN reply         varchar(1000),
    ADD COLUMN replied_at    timestamptz,
    ADD COLUMN replied_by    uuid,
    ADD COLUMN hidden        boolean NOT NULL DEFAULT false,
    ADD COLUMN hidden_reason varchar(300),
    ADD COLUMN hidden_by     uuid,
    ADD COLUMN hidden_at     timestamptz,
    ADD CONSTRAINT reviews_hidden_reason CHECK (NOT hidden OR (hidden_reason IS NOT NULL AND hidden_by IS NOT NULL)),
    ADD CONSTRAINT reviews_reply_pair CHECK ((reply IS NULL) = (replied_at IS NULL));
CREATE INDEX reviews_hidden_idx ON reviews (hidden, created_at DESC);

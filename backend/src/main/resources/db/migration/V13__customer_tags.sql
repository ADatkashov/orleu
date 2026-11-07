-- Free-form customer tags (e.g. "vip", "allergy") used to filter and segment the customer list.
-- Tags are stored lower-case; at most 10 per customer is enforced by the service.
CREATE TABLE customer_tags (
    customer_id  uuid NOT NULL,
    business_id  uuid NOT NULL,
    tag          varchar(30) NOT NULL CHECK (tag = lower(btrim(tag)) AND length(tag) > 0),
    PRIMARY KEY (customer_id, tag),
    FOREIGN KEY (customer_id, business_id) REFERENCES customers(id, business_id) ON DELETE CASCADE
);
CREATE INDEX customer_tags_business_tag_idx ON customer_tags (business_id, tag);

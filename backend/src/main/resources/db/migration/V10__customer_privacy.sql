-- V10: customer privacy tooling. A customer can be anonymised (personal data removed, financial records kept); a business can opt in to
-- automatic anonymisation of customers without activity for N months. These are technical tools, not legal advice.
ALTER TABLE customers ADD COLUMN anonymized_at timestamptz;
ALTER TABLE businesses ADD COLUMN customer_retention_months int CHECK (customer_retention_months IS NULL OR customer_retention_months BETWEEN 12 AND 120);

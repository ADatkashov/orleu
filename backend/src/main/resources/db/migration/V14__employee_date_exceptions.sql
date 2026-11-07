-- Per-date exceptions to a specialist's weekly schedule (V11). For a date that has rows here, THESE rows replace the weekly
-- ranges of that weekday: either one day-off row, or one or more working ranges. Still intersected with the branch hours.
CREATE TABLE employee_date_exceptions (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  uuid NOT NULL,
    employee_id  uuid NOT NULL,
    on_date      date NOT NULL,                 -- business/branch-local calendar date
    day_off      boolean NOT NULL DEFAULT false,
    start_time   time,
    end_time     time,
    CHECK ((day_off AND start_time IS NULL AND end_time IS NULL) OR (NOT day_off AND start_time IS NOT NULL AND end_time > start_time)),
    FOREIGN KEY (employee_id, business_id) REFERENCES employees(id, business_id) ON DELETE CASCADE
);
CREATE INDEX employee_date_exceptions_idx ON employee_date_exceptions (employee_id, on_date);

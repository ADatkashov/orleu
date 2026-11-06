-- V11: personal working hours of a specialist. No rows = the specialist follows the branch hours. With rows, a weekday without rows is a day off
-- and several rows on one weekday model a break (e.g. 09:00-13:00 and 14:00-18:00). Always intersected with the branch hours.
CREATE TABLE employee_hours (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  uuid NOT NULL,
    employee_id  uuid NOT NULL,
    day_of_week  smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    start_time   time NOT NULL,
    end_time     time NOT NULL,
    CHECK (end_time > start_time),
    FOREIGN KEY (employee_id, business_id) REFERENCES employees(id, business_id) ON DELETE CASCADE
);
CREATE INDEX employee_hours_idx ON employee_hours (employee_id, day_of_week);

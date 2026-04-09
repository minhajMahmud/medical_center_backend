BEGIN;

CREATE TABLE IF NOT EXISTS appointment_requests (
  request_id SERIAL PRIMARY KEY,
  patient_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  doctor_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  appointment_date DATE NOT NULL,
  appointment_time TIME WITHOUT TIME ZONE NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  mode TEXT NOT NULL DEFAULT 'In-Person',
  is_urgent BOOLEAN NOT NULL DEFAULT FALSE,
  status TEXT NOT NULL DEFAULT 'PENDING',
  decline_reason TEXT,
  created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
  acted_at TIMESTAMP WITHOUT TIME ZONE,
  CONSTRAINT appointment_requests_status_check
    CHECK (status IN ('PENDING', 'CONFIRMED', 'DECLINED')),
  CONSTRAINT appointment_requests_mode_check
    CHECK (mode IN ('In-Person', 'Video', 'Phone'))
);

CREATE INDEX IF NOT EXISTS idx_appointment_requests_doctor_status_date
  ON appointment_requests (doctor_id, status, appointment_date, appointment_time);

CREATE INDEX IF NOT EXISTS idx_appointment_requests_patient_created
  ON appointment_requests (patient_id, created_at DESC);

COMMIT;

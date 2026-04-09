BEGIN;

ALTER TABLE prescriptions
  ADD COLUMN IF NOT EXISTS bp TEXT;

ALTER TABLE prescriptions
  ADD COLUMN IF NOT EXISTS temperature TEXT;

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

CREATE TABLE IF NOT EXISTS "UploadpatientR" (
  report_id SERIAL PRIMARY KEY,
  patient_id INT NOT NULL REFERENCES users(user_id),
  type TEXT NOT NULL,
  report_date DATE NOT NULL DEFAULT CURRENT_DATE,
  file_path TEXT NOT NULL,
  prescribed_doctor_id INT REFERENCES users(user_id),
  prescription_id INT REFERENCES prescriptions(prescription_id),
  uploaded_by INT REFERENCES users(user_id),
  reviewed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_uploadpatientr_patient
  ON "UploadpatientR"(patient_id, created_at DESC);

ALTER TABLE "UploadpatientR"
  ADD COLUMN IF NOT EXISTS doctor_notes TEXT,
  ADD COLUMN IF NOT EXISTS visible_to_patient BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS review_action TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS reviewed_by INT REFERENCES users(user_id);

COMMIT;

BEGIN;

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

COMMIT;

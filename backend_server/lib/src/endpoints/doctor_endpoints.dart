import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';
import '../utils/auth_user.dart';

class DoctorEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<void> _ensureUploadpatientRReviewColumns(Session session) async {
    await session.db.unsafeExecute('''
      ALTER TABLE "UploadpatientR"
        ADD COLUMN IF NOT EXISTS doctor_notes TEXT,
        ADD COLUMN IF NOT EXISTS visible_to_patient BOOLEAN NOT NULL DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS review_action TEXT,
        ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP,
        ADD COLUMN IF NOT EXISTS reviewed_by INT REFERENCES users(user_id)
    ''');
  }

  Future<void> _backfillUploadedLabResultsForDoctor(
    Session session,
    int doctorId,
  ) async {
    await session.db.unsafeExecute(
      '''
      INSERT INTO "UploadpatientR" (
        patient_id,
        type,
        report_date,
        file_path,
        prescribed_doctor_id,
        prescription_id,
        uploaded_by,
        reviewed,
        created_at
      )
      SELECT
        patient.user_id AS patient_id,
        COALESCE(NULLIF(lt.test_name, ''), 'Lab Test Report') AS type,
        COALESCE(tr.submitted_at::date, tr.created_at::date, CURRENT_DATE) AS report_date,
        tr.attachment_path AS file_path,
        matched_prescription.doctor_id AS prescribed_doctor_id,
        matched_prescription.prescription_id AS prescription_id,
        NULL AS uploaded_by,
        FALSE AS reviewed,
        COALESCE(tr.submitted_at, tr.created_at, NOW()) AS created_at
      FROM test_results tr
      LEFT JOIN lab_tests lt ON lt.test_id = tr.test_id
      JOIN users patient
        ON RIGHT(REGEXP_REPLACE(COALESCE(patient.phone, ''), '[^0-9]', '', 'g'), 11)
         = RIGHT(REGEXP_REPLACE(COALESCE(tr.mobile_number, ''), '[^0-9]', '', 'g'), 11)
      JOIN LATERAL (
        SELECT p.prescription_id, p.doctor_id
        FROM prescriptions p
        WHERE p.patient_id = patient.user_id
          AND p.doctor_id = @doctorId
        ORDER BY
          CASE
            WHEN COALESCE(lt.test_name, '') <> ''
             AND COALESCE(NULLIF(TRIM(p.test), ''), '') <> ''
             AND LOWER(p.test) LIKE '%' || LOWER(COALESCE(lt.test_name, '')) || '%'
            THEN 0
            ELSE 1
          END,
          p.prescription_date DESC,
          p.prescription_id DESC
        LIMIT 1
      ) matched_prescription ON TRUE
      WHERE COALESCE(tr.is_uploaded, FALSE) = TRUE
        AND COALESCE(tr.attachment_path, '') <> ''
        AND NOT EXISTS (
          SELECT 1
          FROM "UploadpatientR" r
          WHERE r.patient_id = patient.user_id
            AND r.prescribed_doctor_id = matched_prescription.doctor_id
            AND COALESCE(r.file_path, '') = COALESCE(tr.attachment_path, '')
        )
      ''',
      parameters: QueryParameters.named({'doctorId': doctorId}),
    );
  }

  Future<void> _ensureAppointmentTables(Session session) async {
    await session.db.unsafeExecute('''
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
      )
    ''');

    await session.db.unsafeExecute('''
      CREATE INDEX IF NOT EXISTS idx_appointment_requests_doctor_status_date
      ON appointment_requests (doctor_id, status, appointment_date, appointment_time)
    ''');

    await session.db.unsafeExecute('''
      CREATE INDEX IF NOT EXISTS idx_appointment_requests_patient_created
      ON appointment_requests (patient_id, created_at DESC)
    ''');
  }

  /// Doctor home dashboard data
// ----------------------------
  Future<DoctorHomeData> getDoctorHomeData(Session session) async {
    try {
      final resolvedDoctorId = requireAuthenticatedUserId(session);

      await _backfillUploadedLabResultsForDoctor(session, resolvedDoctorId);

      final doctorRow = await session.db.unsafeQuery(
        'SELECT name, role::text AS role, profile_picture_url FROM users WHERE user_id = @id LIMIT 1',
        parameters: QueryParameters.named({'id': resolvedDoctorId}),
      );

      String doctorName;
      String doctorProfilePictureUrl;
      String doctorRoleRaw;

      if (doctorRow.isNotEmpty) {
        doctorName = _decode(doctorRow.first.toColumnMap()['name']);
        doctorProfilePictureUrl =
            _decode(doctorRow.first.toColumnMap()['profile_picture_url']);
        doctorRoleRaw = _decode(doctorRow.first.toColumnMap()['role']);
      } else {
        doctorName = '';
        doctorProfilePictureUrl = '';
        doctorRoleRaw = '';
      }

      String friendlyRole(String raw) {
        final r = raw.trim().toUpperCase();
        switch (r) {
          case 'DOCTOR':
            return 'Doctor';
          case 'LABSTAFF':
            return 'Lab Technician';
          case 'DISPENSER':
            return 'Dispenser';
          case 'ADMIN':
            return 'Admin';
          case 'STAFF':
            return 'Staff';
          case 'TEACHER':
            return 'Teacher';
          case 'STUDENT':
            return 'Student';
          case 'OUTSIDE':
            return 'Outside';
          default:
            return raw.trim().isEmpty ? '' : raw.trim();
        }
      }

      // Last month (rolling 1 month)
      final lastMonthRows = await session.db.unsafeQuery(
        r'''
        SELECT COUNT(*)::int AS total
        FROM prescriptions
        WHERE doctor_id = @id
          AND prescription_date >= (CURRENT_DATE - INTERVAL '1 month')
        ''',
        parameters: QueryParameters.named({'id': resolvedDoctorId}),
      );

      final lastMonthPrescriptions = lastMonthRows.isNotEmpty
          ? (lastMonthRows.first.toColumnMap()['total'] as int? ?? 0)
          : 0;

      final previousMonthRows = await session.db.unsafeQuery(
        r'''
        SELECT COUNT(*)::int AS total
        FROM prescriptions
        WHERE doctor_id = @id
          AND prescription_date >= (CURRENT_DATE - INTERVAL '2 month')
          AND prescription_date < (CURRENT_DATE - INTERVAL '1 month')
        ''',
        parameters: QueryParameters.named({'id': resolvedDoctorId}),
      );

      final previousMonthPrescriptions = previousMonthRows.isNotEmpty
          ? (previousMonthRows.first.toColumnMap()['total'] as int? ?? 0)
          : 0;

      // Last 7 days inclusive => CURRENT_DATE - 6 days
      final lastWeekRows = await session.db.unsafeQuery(
        r'''
        SELECT COUNT(*)::int AS total
        FROM prescriptions
        WHERE doctor_id = @id
          AND prescription_date >= (CURRENT_DATE - INTERVAL '6 days')
        ''',
        parameters: QueryParameters.named({'id': resolvedDoctorId}),
      );

      final lastWeekPrescriptions = lastWeekRows.isNotEmpty
          ? (lastWeekRows.first.toColumnMap()['total'] as int? ?? 0)
          : 0;

      final previousWeekRows = await session.db.unsafeQuery(
        r'''
        SELECT COUNT(*)::int AS total
        FROM prescriptions
        WHERE doctor_id = @id
          AND prescription_date >= (CURRENT_DATE - INTERVAL '13 days')
          AND prescription_date < (CURRENT_DATE - INTERVAL '6 days')
        ''',
        parameters: QueryParameters.named({'id': resolvedDoctorId}),
      );

      final previousWeekPrescriptions = previousWeekRows.isNotEmpty
          ? (previousWeekRows.first.toColumnMap()['total'] as int? ?? 0)
          : 0;

      final todayRows = await session.db.unsafeQuery(
        r'''
        SELECT COUNT(*)::int AS total
        FROM prescriptions
        WHERE doctor_id = @id
          AND prescription_date = CURRENT_DATE
        ''',
        parameters: QueryParameters.named({'id': resolvedDoctorId}),
      );

      final todayPrescriptions = todayRows.isNotEmpty
          ? (todayRows.first.toColumnMap()['total'] as int? ?? 0)
          : 0;

      final yesterdayRows = await session.db.unsafeQuery(
        r'''
        SELECT COUNT(*)::int AS total
        FROM prescriptions
        WHERE doctor_id = @id
          AND prescription_date = (CURRENT_DATE - INTERVAL '1 day')::date
        ''',
        parameters: QueryParameters.named({'id': resolvedDoctorId}),
      );

      final yesterdayPrescriptions = yesterdayRows.isNotEmpty
          ? (yesterdayRows.first.toColumnMap()['total'] as int? ?? 0)
          : 0;

      final now = DateTime.now();

      // Recent activity: last 24 hours (for dashboard)
      final recentRows = await session.db.unsafeQuery(
        r'''
        SELECT prescription_id, name, created_at
        FROM prescriptions
        WHERE doctor_id = @id
          AND created_at IS NOT NULL
          AND created_at >= (NOW() - INTERVAL '24 hours')
        ORDER BY created_at DESC NULLS LAST, prescription_id DESC
        LIMIT 300
        ''',
        parameters: QueryParameters.named({'id': resolvedDoctorId}),
      );

      final recent = <DoctorHomeRecentItem>[];
      for (final r in recentRows) {
        final m = r.toColumnMap();
        final createdAt = m['created_at'] as DateTime?;

        if (createdAt == null) continue;

        recent.add(
          DoctorHomeRecentItem(
            title: 'Prescription created',
            subtitle: _s(m['name']),
            timeAgo: _timeAgo(createdAt, now),
            type: 'prescription',
            prescriptionId: m['prescription_id'] as int?,
          ),
        );
      }

      // Reviewed reports: last 24 hours (for dashboard)
      final reportRows = await session.db.unsafeQuery(
        r'''
        SELECT
          r.report_id,
          r.type,
          r.report_date,
          COALESCE(r.created_at, r.report_date::timestamp, NOW()) AS effective_created_at,
          COALESCE(
            r.prescription_id,
            p.prescription_id,
            (
              SELECT p2.prescription_id
              FROM prescriptions p2
              WHERE p2.patient_id = r.patient_id
                AND p2.doctor_id = COALESCE(r.prescribed_doctor_id, p.doctor_id, @id)
              ORDER BY p2.prescription_id DESC
              LIMIT 1
            )
          ) AS effective_prescription_id,
          COALESCE(u.name, '') AS uploaded_by_name
        FROM "UploadpatientR" r
        LEFT JOIN prescriptions p ON p.prescription_id = r.prescription_id
        LEFT JOIN users u ON u.user_id = r.uploaded_by
        WHERE COALESCE(r.prescribed_doctor_id, p.doctor_id) = @id
          AND (
            (r.created_at IS NOT NULL AND r.created_at >= (NOW() - INTERVAL '24 hours'))
            OR (r.report_date IS NOT NULL AND r.report_date >= (CURRENT_DATE - INTERVAL '1 day'))
          )
        ORDER BY effective_created_at DESC NULLS LAST, r.report_id DESC
        LIMIT 300
        ''',
        parameters: QueryParameters.named({'id': resolvedDoctorId}),
      );

      final reviewedReports = <DoctorHomeReviewedReport>[];
      for (final r in reportRows) {
        final m = r.toColumnMap();
        final createdAt = m['effective_created_at'] as DateTime?;

        if (createdAt == null) continue;

        reviewedReports.add(
          DoctorHomeReviewedReport(
            reportId: m['report_id'] as int?,
            type: _s(m['type']),
            uploadedByName: _s(m['uploaded_by_name']),
            prescriptionId: m['effective_prescription_id'] as int?,
            timeAgo: _timeAgo(createdAt, now),
          ),
        );
      }

      final nextFollowUpRows = await session.db.unsafeQuery(
        r'''
        SELECT name, next_visit, prescription_id, prescription_date
        FROM prescriptions
        WHERE doctor_id = @id
          AND COALESCE(TRIM(next_visit), '') <> ''
        ORDER BY prescription_date DESC NULLS LAST, prescription_id DESC
        LIMIT 1
        ''',
        parameters: QueryParameters.named({'id': resolvedDoctorId}),
      );

      String? nextFollowUpPatientName;
      String? nextFollowUpNote;
      if (nextFollowUpRows.isNotEmpty) {
        final map = nextFollowUpRows.first.toColumnMap();
        nextFollowUpPatientName = _s(map['name']);
        final rawNote = _s(map['next_visit']);
        final rawDate = map['prescription_date'] as DateTime?;
        final dateLabel = rawDate == null
            ? ''
            : '${rawDate.day}/${rawDate.month}/${rawDate.year}';
        nextFollowUpNote = rawNote.isEmpty
            ? dateLabel
            : (dateLabel.isEmpty ? rawNote : '$rawNote • $dateLabel');
      }

      return DoctorHomeData(
        doctorName: doctorName,
        doctorDesignation: friendlyRole(doctorRoleRaw),
        doctorProfilePictureUrl:
            doctorProfilePictureUrl.isEmpty ? null : doctorProfilePictureUrl,
        today: DateTime.now().toUtc(),
        todayPrescriptions: todayPrescriptions,
        yesterdayPrescriptions: yesterdayPrescriptions,
        lastMonthPrescriptions: lastMonthPrescriptions,
        previousMonthPrescriptions: previousMonthPrescriptions,
        lastWeekPrescriptions: lastWeekPrescriptions,
        previousWeekPrescriptions: previousWeekPrescriptions,
        nextFollowUpPatientName: nextFollowUpPatientName,
        nextFollowUpNote: nextFollowUpNote,
        recent: recent,
        reviewedReports: reviewedReports,
      );
    } catch (e, st) {
      session.log(
        'getDoctorHomeData failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );

      return DoctorHomeData(
        doctorName: '',
        doctorDesignation: '',
        doctorProfilePictureUrl: null,
        today: DateTime.now().toUtc(),
        todayPrescriptions: 0,
        yesterdayPrescriptions: 0,
        lastMonthPrescriptions: 0,
        previousMonthPrescriptions: 0,
        lastWeekPrescriptions: 0,
        previousWeekPrescriptions: 0,
        nextFollowUpPatientName: null,
        nextFollowUpNote: null,
        recent: const [],
        reviewedReports: const [],
      );
    }
  }

  // Doctor info (name + signature)
  // ----------------------------
  Future<Map<String, String?>> getDoctorInfo(Session session) async {
    try {
      final resolvedDoctorId = requireAuthenticatedUserId(session);

      final res = await session.db.unsafeQuery(
        r'''
        SELECT u.name, s.signature_url
        FROM users u
        JOIN staff_profiles s ON u.user_id = s.user_id
        WHERE u.user_id = @id
        ''',
        parameters: QueryParameters.named({'id': resolvedDoctorId}),
      );

      if (res.isEmpty) return {'name': '', 'signature': ''};

      final row = res.first.toColumnMap();
      return {
        'name': _decode(row['name']),
        'signature': _decode(row['signature_url']),
      };
    } catch (_) {
      return {'name': '', 'signature': ''};
    }
  }

  /// ডাক্তারের আইডি দিয়ে তার সই এবং নাম খুঁজে বের করা
  Future<DoctorProfile?> getDoctorProfile(Session session, int doctorId) async {
    try {
      final resolvedDoctorId = requireAuthenticatedUserId(session);
      final res = await session.db.unsafeQuery('''
      SELECT u.user_id, u.name, u.email, u.phone, u.profile_picture_url,
             s.designation, s.qualification, s.signature_url
      FROM users u
      LEFT JOIN staff_profiles s ON u.user_id = s.user_id
      WHERE u.user_id = @id
      LIMIT 1
    ''', parameters: QueryParameters.named({'id': resolvedDoctorId}));

      if (res.isEmpty) return null;

      final row = res.first.toColumnMap();

      return DoctorProfile(
        userId: row['user_id'] as int?,
        name: _decode(row['name']),
        email: _decode(row['email']),
        phone: _decode(row['phone']),
        profilePictureUrl: _decode(row['profile_picture_url']),
        designation: _decode(row['designation']),
        qualification: _decode(row['qualification']),
        signatureUrl: _decode(row['signature_url']),
      );
    } catch (e, st) {
      session.log(
        'getDoctorProfile failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Update doctor's user and staff profile. If staff_profiles row doesn't exist, insert it.
  /// Expects profilePictureUrl and signatureUrl to be remote URLs (uploads happen on frontend).
  Future<bool> updateDoctorProfile(
    Session session,
    int doctorId,
    String name,
    String email,
    String phone,
    String? profilePictureUrl,
    String? designation,
    String? qualification,
    String? signatureUrl,
  ) async {
    try {
      final resolvedDoctorId = requireAuthenticatedUserId(session);
      // Pre-check for duplicate phone (different user)
      final dup = await session.db.unsafeQuery(
        'SELECT 1 FROM users WHERE phone = @ph AND user_id <> @id LIMIT 1',
        parameters:
            QueryParameters.named({'ph': phone, 'id': resolvedDoctorId}),
      );

      if (dup.isNotEmpty) {
        // Return a clear error to client by throwing - client will receive the message
        throw Exception('Phone number already registered');
      }

      String? normalizeUrl(String? value) {
        if (value == null) return null;
        final s = value.trim();
        if (s.isEmpty) return null;
        if (s.startsWith('http://') || s.startsWith('https://')) return s;
        return null;
      }

      final String? finalProfileUrl = normalizeUrl(profilePictureUrl);
      final String? finalSignatureUrl = normalizeUrl(signatureUrl);

      await session.db.unsafeExecute('BEGIN');

      // Update users table (name, phone, profile picture)
      await session.db.unsafeExecute('''
        UPDATE users
        SET name = @name,email = @email, phone = @phone, profile_picture_url = COALESCE(@pp, profile_picture_url)
        WHERE user_id = @id
      ''',
          parameters: QueryParameters.named({
            'name': name,
            'email': email.trim(),
            'phone': phone,
            'pp': finalProfileUrl,
            'id': resolvedDoctorId
          }));

      // Check if staff_profiles exists
      final exists = await session.db.unsafeQuery(
          'SELECT 1 FROM staff_profiles WHERE user_id = @id',
          parameters: QueryParameters.named({'id': resolvedDoctorId}));

      if (exists.isEmpty) {
        // insert
        await session.db.unsafeExecute('''
          INSERT INTO staff_profiles (user_id, designation, qualification, signature_url)
          VALUES (@id, @spec, @qual, @sig)
        ''',
            parameters: QueryParameters.named({
              'id': resolvedDoctorId,
              'spec': designation,
              'qual': qualification,
              'sig': finalSignatureUrl
            }));
      } else {
        await session.db.unsafeExecute('''
          UPDATE staff_profiles
          SET designation = @spec, qualification = @qual, signature_url = COALESCE(@sig, signature_url)
          WHERE user_id = @id
        ''',
            parameters: QueryParameters.named({
              'spec': designation,
              'qual': qualification,
              'sig': finalSignatureUrl,
              'id': resolvedDoctorId
            }));
      }

      await session.db.unsafeExecute('COMMIT');
      return true;
    } catch (e, st) {
      await session.db.unsafeExecute('ROLLBACK');
      session.log('updateDoctorProfile failed: $e',
          level: LogLevel.error, stackTrace: st);
      return false;
    }
  }

  Future<Map<String, String?>> getPatientByPhone(
      Session session, String phone) async {
    try {
      final queryText = phone.trim();
      final cleaned = queryText.replaceAll(RegExp(r'[^0-9]'), '');

      // Normalize phone to local last 11 digits (supports +88... inputs)
      final normalizedPhonePrefix = cleaned.isEmpty
          ? ''
          : (cleaned.length >= 11
              ? cleaned.substring(cleaned.length - 11)
              : cleaned);

      session.log(
        'Searching patient by query="$queryText", phonePrefix="$normalizedPhonePrefix"',
        level: LogLevel.info,
      );

      // Search by name OR phone prefix (normalized 11-digit local number)
      final res = await session.db.unsafeQuery(
        '''
        SELECT
          u.user_id,
          u.name,
          u.phone,
          p.gender,
          p.blood_group,
          p.date_of_birth,
          EXTRACT(YEAR FROM age(CURRENT_DATE, p.date_of_birth))::int AS age
        FROM users u
        LEFT JOIN patient_profiles p ON p.user_id = u.user_id
        WHERE u.phone IS NOT NULL
          AND lower(u.role::text) IN ('student', 'teacher', 'staff', 'outside')
          AND (
            (@nameQuery <> '' AND LOWER(u.name) LIKE LOWER(@nameLike))
            OR
            (@phonePrefix <> '' AND RIGHT(REPLACE(REPLACE(u.phone, ' ', ''), '-', ''), 11) LIKE @phoneLikePrefix)
          )
        ORDER BY
          CASE
            WHEN @phonePrefix <> '' AND RIGHT(REPLACE(REPLACE(u.phone, ' ', ''), '-', ''), 11) = @phonePrefix THEN 0
            ELSE 1
          END,
          u.user_id DESC
        LIMIT 1
        ''',
        parameters: QueryParameters.named({
          'nameQuery': queryText,
          'nameLike': '%$queryText%',
          'phonePrefix': normalizedPhonePrefix,
          'phoneLikePrefix': '$normalizedPhonePrefix%',
        }),
      );

      if (res.isEmpty) {
        session.log(
          'Patient not found with query: $queryText',
          level: LogLevel.warning,
        );
        return {'id': null, 'name': null};
      }

      final row = res.first.toColumnMap();
      final userId = row['user_id']?.toString();
      final name = _decode(row['name']);
      final phoneStr = _decode(row['phone']);

      final dob = row['date_of_birth'];
      final dobStr = dob?.toString();

      final genderStr = row['gender']?.toString();
      final bloodGroupStr = row['blood_group']?.toString();

      final ageVal = row['age'];
      final ageStr = ageVal?.toString();

      session.log('Patient found: ID=$userId, Name=$name',
          level: LogLevel.info);

      return {
        'id': userId,
        'name': name,
        'phone': phoneStr,
        'gender': genderStr,
        'bloodGroup': bloodGroupStr,
        'dateOfBirth': dobStr,
        'age': ageStr,
      };
    } catch (e) {
      session.log('Error in getPatientByPhone: $e', level: LogLevel.error);
      return {'id': null, 'name': null};
    }
  }

  /// নতুন প্রেসক্রিপশন সেভ করা
  Future<int> createPrescription(
    Session session,
    Prescription prescription,
    List<PrescribedItem> items,
    String patientPhone,
  ) async {
    try {
      final resolvedDoctorId = requireAuthenticatedUserId(session);
      final patientData = await getPatientByPhone(session, patientPhone);

      int? foundPatientId;
      if (patientData['id'] != null) {
        foundPatientId = int.tryParse(patientData['id']!);
      }

      await session.db.unsafeExecute('BEGIN');

      // If no patient exists for the provided phone, create an OUTSIDE patient
      // so both web_app and mobile_app can still store prescriptions.
      if (foundPatientId == null) {
        final digitsOnly = patientPhone.replaceAll(RegExp(r'[^0-9]'), '');
        final normalizedPhone = digitsOnly.length > 11
            ? digitsOnly.substring(digitsOnly.length - 11)
            : digitsOnly;

        final displayName = (prescription.name ?? '').trim().isEmpty
            ? 'Outside Patient'
            : prescription.name!.trim();

        final ts = DateTime.now().millisecondsSinceEpoch;
        final safePhonePart =
            normalizedPhone.isEmpty ? 'unknown' : normalizedPhone;
        final generatedEmail = 'outside_${safePhonePart}_$ts@nstu.local';

        final newUserRows = await session.db.unsafeQuery(
          '''
          INSERT INTO users (
            name, email, password_hash, phone, role, is_active, email_otp_verified
          ) VALUES (
            @name, @email, @pwd, @phone, CAST(@role AS user_role), true, true
          ) RETURNING user_id
          ''',
          parameters: QueryParameters.named({
            'name': displayName,
            'email': generatedEmail,
            'pwd': 'NO_LOGIN_PROFILE',
            'phone': normalizedPhone.isEmpty ? null : normalizedPhone,
            'role': 'outside',
          }),
        );

        if (newUserRows.isEmpty) {
          await session.db.unsafeExecute('ROLLBACK');
          return -1;
        }

        foundPatientId = newUserRows.first.toColumnMap()['user_id'] as int;

        await session.db.unsafeExecute(
          '''
          INSERT INTO patient_profiles (user_id, gender)
          VALUES (@uid, @gender)
          ON CONFLICT (user_id) DO UPDATE SET gender = EXCLUDED.gender
          ''',
          parameters: QueryParameters.named({
            'uid': foundPatientId,
            'gender': prescription.gender,
          }),
        );
      }

      // Insert prescription
      final res = await session.db.unsafeQuery('''
    INSERT INTO prescriptions (
      patient_id, doctor_id, name, age, mobile_number, gender,
      prescription_date, cc, oe, bp, temperature, advice, test, next_visit, is_outside
    ) VALUES (
      @pid, @did, @name, @age, @mobile, @gender,
      @pdate, @cc, @oe, @bp, @temperature, @advice, @test, @nextVisit, @iso
    ) RETURNING prescription_id
    ''',
          parameters: QueryParameters.named({
            'pid': foundPatientId,
            'did': resolvedDoctorId,
            'name': prescription.name,
            'age': prescription.age,
            'mobile': prescription.mobileNumber,
            'gender': prescription.gender,
            'pdate': prescription.prescriptionDate ?? DateTime.now(),
            'cc': prescription.cc,
            'oe': prescription.oe,
            'bp': prescription.bp,
            'temperature': prescription.temperature,
            'advice': prescription.advice,
            'test': prescription.test,
            'nextVisit': prescription.nextVisit,
            'iso': prescription.isOutside ?? false,
          }));

      if (res.isEmpty) {
        await session.db.unsafeExecute('ROLLBACK');
        return -1;
      }

      final prescriptionId = res.first.toColumnMap()['prescription_id'] as int;

      // Insert prescribed items
      for (var item in items) {
        await session.db.unsafeExecute('''
      INSERT INTO prescribed_items (
        prescription_id, medicine_name, dosage_times, meal_timing, duration
      ) VALUES (@preId, @mname, @dtimes, @mtiming, @dur)
      ''',
            parameters: QueryParameters.named({
              'preId': prescriptionId,
              'mname': item.medicineName,
              'dtimes': item.dosageTimes,
              'mtiming': item.mealTiming,
              'dur': item.duration, // Ensure this is passed as an int
            }));
      }

      await session.db.unsafeExecute(
        '''
        INSERT INTO notifications (user_id, title, message, is_read, created_at)
        VALUES (
          @patientId,
          'New Prescription',
          @message,
          FALSE,
          NOW()
        )
        ''',
        parameters: QueryParameters.named({
          'patientId': foundPatientId,
          'message':
              'A new prescription has been added to your account. Prescription ID: $prescriptionId',
        }),
      );

      await session.db.unsafeExecute('COMMIT');
      return prescriptionId;
    } catch (e, st) {
      await session.db.unsafeExecute('ROLLBACK');
      session.log('createPrescription failed: $e',
          level: LogLevel.error, stackTrace: st);
      return -1;
    }
  }

  // ডাক্তারের কাছে আসা রিপোর্টগুলো দেখার জন্য
  Future<List<PatientExternalReport>> getReportsForDoctor(
      Session session, int doctorId) async {
    try {
      final resolvedDoctorId = requireAuthenticatedUserId(session);
      await _ensureUploadpatientRReviewColumns(session);
      await _backfillUploadedLabResultsForDoctor(session, resolvedDoctorId);
      final res = await session.db.unsafeQuery('''
      SELECT
        r.*,
        COALESCE(r.created_at, r.report_date::timestamp, NOW()) AS effective_created_at,
        COALESCE(
          r.prescribed_doctor_id,
          p.doctor_id,
          (
            SELECT p3.doctor_id
            FROM prescriptions p3
            WHERE p3.patient_id = r.patient_id
            ORDER BY p3.prescription_id DESC
            LIMIT 1
          )
        ) AS effective_doctor_id,
        COALESCE(
          r.prescription_id,
          (
            SELECT p2.prescription_id
            FROM prescriptions p2
            WHERE p2.patient_id = r.patient_id
              AND p2.doctor_id = COALESCE(r.prescribed_doctor_id, p.doctor_id, @id)
            ORDER BY p2.prescription_id DESC
            LIMIT 1
          )
        ) AS effective_prescription_id
      FROM "UploadpatientR" r
      LEFT JOIN prescriptions p ON p.prescription_id = r.prescription_id
      WHERE COALESCE(r.prescribed_doctor_id, p.doctor_id) = @id
      ORDER BY effective_created_at DESC, r.report_id DESC
    ''', parameters: QueryParameters.named({'id': resolvedDoctorId}));

      final reports = res.map((row) {
        final map = row.toColumnMap();
        final report = PatientExternalReport(
          reportId: map['report_id'] as int?,
          patientId: map['patient_id'] as int? ?? 0,
          type: map['type'] as String? ?? '',
          reportDate: map['report_date'] as DateTime? ?? DateTime.now(),
          filePath: map['file_path'] as String? ?? '',
          prescribedDoctorId: map['effective_doctor_id'] as int? ?? 0,
          prescriptionId: map['effective_prescription_id'] as int?,
          uploadedBy: map['uploaded_by'] as int? ?? 0,
          reviewed: (map['reviewed'] as bool?) ?? false,
          createdAt: map['effective_created_at'] as DateTime?,
          doctorNotes: map['doctor_notes'] as String?,
          visibleToPatient: (map['visible_to_patient'] as bool?) ?? false,
          reviewAction: map['review_action'] as String?,
          reviewedAt: map['reviewed_at'] as DateTime?,
          reviewedBy: map['reviewed_by'] as int?,
        );
        session.log(
            '[DoctorReport] id=${report.reportId ?? 'null'} patient=${report.patientId} type=${report.type} filePath=${report.filePath} prescId=${report.prescriptionId} reviewed=${report.reviewed}',
            level: LogLevel.info);
        return report;
      }).toList();
      return reports;
    } catch (e) {
      session.log('Error fetching reports: $e', level: LogLevel.error);
      return [];
    }
  }

  /// Track if a test report was reviewed by the assigned doctor.
  Future<bool> markReportReviewed(Session session, int reportId) async {
    try {
      final resolvedDoctorId = requireAuthenticatedUserId(session);

      final updatedRows = await session.db.unsafeQuery(
        '''
        UPDATE "UploadpatientR"
        SET
          reviewed = TRUE,
          prescribed_doctor_id = COALESCE(prescribed_doctor_id, @did)
        WHERE report_id = @rid
          AND (
            prescribed_doctor_id = @did
            OR (
              prescribed_doctor_id IS NULL
              AND EXISTS (
                SELECT 1
                FROM prescriptions p
                WHERE p.prescription_id = "UploadpatientR".prescription_id
                  AND p.doctor_id = @did
              )
            )
          )
        RETURNING patient_id, type, prescription_id
        ''',
        parameters:
            QueryParameters.named({'rid': reportId, 'did': resolvedDoctorId}),
      );

      if (updatedRows.isEmpty) return false;

      final row = updatedRows.first.toColumnMap();
      final patientId = row['patient_id'] as int?;
      final type = _s(row['type']);
      final prescriptionId = row['prescription_id'] as int?;

      if (patientId != null) {
        await session.db.unsafeExecute(
          '''
          INSERT INTO notifications (user_id, title, message, is_read, created_at)
          VALUES (@uid, 'Report Reviewed', @message, FALSE, NOW())
          ''',
          parameters: QueryParameters.named({
            'uid': patientId,
            'message':
                'Your ${type.isEmpty ? 'lab' : type} report has been reviewed by doctor.${prescriptionId == null ? '' : ' Prescription ID: $prescriptionId'}',
          }),
        );
      }

      return true;
    } catch (e, st) {
      session.log(
        'markReportReviewed failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Submit a full doctor review: clinical notes, action, patient portal visibility.
  Future<bool> submitDoctorReview(
    Session session,
    int reportId,
    String notes,
    String action,
    bool visibleToPatient,
  ) async {
    try {
      final resolvedDoctorId = requireAuthenticatedUserId(session);
      await _ensureUploadpatientRReviewColumns(session);
      final trimmedNotes = notes.trim();
      final normalizedAction =
          action.trim().isEmpty ? 'No Action' : action.trim();

      final updatedRows = await session.db.unsafeQuery(
        '''
        UPDATE "UploadpatientR"
        SET
          reviewed = TRUE,
          prescribed_doctor_id = COALESCE(prescribed_doctor_id, @did),
          doctor_notes = @notes,
          review_action = @action,
          visible_to_patient = @visible,
          reviewed_at = NOW(),
          reviewed_by = @did
        WHERE report_id = @rid
          AND (
            prescribed_doctor_id = @did
            OR (
              prescribed_doctor_id IS NULL
              AND (
                EXISTS (
                  SELECT 1
                  FROM prescriptions p
                  WHERE p.prescription_id = "UploadpatientR".prescription_id
                    AND p.doctor_id = @did
                )
                OR EXISTS (
                  SELECT 1
                  FROM prescriptions p
                  WHERE p.patient_id = "UploadpatientR".patient_id
                    AND p.doctor_id = @did
                )
              )
            )
          )
        RETURNING patient_id, type, prescription_id
        ''',
        parameters: QueryParameters.named({
          'rid': reportId,
          'did': resolvedDoctorId,
          'notes': trimmedNotes,
          'action': normalizedAction,
          'visible': visibleToPatient,
        }),
      );

      if (updatedRows.isEmpty) {
        session.log(
          'submitDoctorReview updated 0 rows for reportId=$reportId doctorId=$resolvedDoctorId',
          level: LogLevel.warning,
        );
        return false;
      }

      final row = updatedRows.first.toColumnMap();
      final patientId = row['patient_id'] as int?;
      final type = _s(row['type']);

      if (patientId != null) {
        try {
          final noteText = trimmedNotes.isEmpty ? '' : ' Notes: $trimmedNotes';
          await session.db.unsafeExecute(
            '''
            INSERT INTO notifications (user_id, title, message, is_read, created_at)
            VALUES (@uid, @title, @message, FALSE, NOW())
            ''',
            parameters: QueryParameters.named({
              'uid': patientId,
              'title': 'Doctor Review: $normalizedAction',
              'message':
                  'Your ${type.isEmpty ? 'lab' : type} report has been reviewed by your doctor. Action: $normalizedAction.$noteText',
            }),
          );
        } catch (notifyError, notifyStack) {
          session.log(
            'submitDoctorReview notification failed: $notifyError',
            level: LogLevel.warning,
            stackTrace: notifyStack,
          );
        }
      }

      return true;
    } catch (e, st) {
      session.log(
        'submitDoctorReview failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
      return false;
    }
  }

//update Prescription
  Future<int> revisePrescription(
    Session session, {
    required int originalPrescriptionId,
    required String newAdvice,
    required List<PrescribedItem> newItems,
  }) async {
    try {
      final resolvedDoctorId = requireAuthenticatedUserId(session);
      await session.db.unsafeExecute('BEGIN');

      // ১. পুরনো প্রেসক্রিপশনের তথ্য কপি করা
      final oldPres = await session.db.unsafeQuery(
          'SELECT * FROM prescriptions WHERE prescription_id = @id',
          parameters: QueryParameters.named({'id': originalPrescriptionId}));
      if (oldPres.isEmpty) return -1;
      final pData = oldPres.first.toColumnMap();

      // Only allow revising prescriptions created by this doctor
      if (pData['doctor_id'] != resolvedDoctorId) {
        await session.db.unsafeExecute('ROLLBACK');
        return -1;
      }

      // ২. নতুন (Revised) প্রেসক্রিপশন তৈরি
      final res = await session.db.unsafeQuery('''
      INSERT INTO prescriptions (
        patient_id, doctor_id, name, age, mobile_number, gender,
        cc, oe, bp, temperature, advice, test, revised_from_id
      ) VALUES (
        @pid, @did, @name, @age, @mobile, @gender,
        @cc, @oe, @bp, @temperature, @advice, @test, @revisedId
      ) RETURNING prescription_id
    ''',
          parameters: QueryParameters.named({
            'pid': pData['patient_id'],
            'did': resolvedDoctorId,
            'name': pData['name'],
            'age': pData['age'],
            'mobile': pData['mobile_number'],
            'gender': pData['gender'],
            'cc': pData['cc'],
            'oe': pData['oe'],
            'bp': pData['bp'],
            'temperature': pData['temperature'],
            'advice': newAdvice,
            'test': pData['test'],
            'revisedId': originalPrescriptionId,
          }));

      final newId = res.first.toColumnMap()['prescription_id'] as int;

      // ৩. নতুন ওষুধগুলো যোগ করা
      for (var item in newItems) {
        await session.db.unsafeExecute('''
        INSERT INTO prescribed_items (prescription_id, medicine_name, dosage_times, meal_timing, duration)
        VALUES (@preId, @mname, @dtimes, @mtiming, @dur)
      ''',
            parameters: QueryParameters.named({
              'preId': newId,
              'mname': item.medicineName,
              'dtimes': item.dosageTimes,
              'mtiming': item.mealTiming,
              'dur': item.duration,
            }));
      }

      // ৪. পেশেন্টকে নোটিফিকেশন পাঠানো
      await session.db.unsafeExecute('''
      INSERT INTO notifications (user_id, title, message, is_read)
      VALUES (@pId, 'Prescription Updated', 'Your doctor has updated your prescription after reviewing your report.', false)
    ''', parameters: QueryParameters.named({'pId': pData['patient_id']}));

      // Keep reports linked to the latest revised prescription so reopening
      // the same test shows latest prescription details.
      await session.db.unsafeExecute(
        '''
        UPDATE "UploadpatientR"
        SET prescription_id = @newId
        WHERE prescription_id = @oldId
          AND prescribed_doctor_id = @did
        ''',
        parameters: QueryParameters.named({
          'newId': newId,
          'oldId': originalPrescriptionId,
          'did': resolvedDoctorId,
        }),
      );

      await session.db.unsafeExecute('COMMIT');
      return newId;
    } catch (e) {
      await session.db.unsafeExecute('ROLLBACK');
      return -1;
    }
  }

  /// List page: all prescriptions (latest first) + optional search by name/phone
  Future<List<PatientPrescriptionListItem>> getPatientPrescriptionList(
    Session session, {
    String? query,
    int limit = 100,
    int offset = 0,
  }) async {
    final resolvedDoctorId = requireAuthenticatedUserId(session);
    final q = (query ?? '').trim();

    final rows = await session.db.unsafeQuery(r'''
      SELECT
        pr.prescription_id,
        pr.name,
        pr.mobile_number,
        pp.blood_group,
        pr.gender,
        pr.age,
        pr.prescription_date
      FROM prescriptions pr
      LEFT JOIN patient_profiles pp ON pp.user_id = pr.patient_id
      WHERE
        pr.doctor_id = @did AND
        (@q = '' OR
         LOWER(pr.name) LIKE LOWER(@likeQ) OR
         RIGHT(REPLACE(REPLACE(pr.mobile_number, ' ', ''), '-', ''), 11) LIKE @phoneLikePrefix)
      ORDER BY pr.prescription_id DESC
      LIMIT @limit OFFSET @offset
    ''',
        parameters: QueryParameters.named({
          'did': resolvedDoctorId,
          'q': q,
          'likeQ': '%$q%',
          'phoneLikePrefix': '${q.replaceAll(RegExp(r'[^0-9]'), '')}%',
          'limit': limit,
          'offset': offset,
        }));

    return rows.map((r) {
      final m = r.toColumnMap();
      return PatientPrescriptionListItem(
        prescriptionId: m['prescription_id'] as int,
        name: _s(m['name']),
        mobileNumber: m['mobile_number']?.toString(),
        bloodGroup: m['blood_group']?.toString(),
        gender: m['gender']?.toString(),
        age: m['age'] as int?,
        prescriptionDate: m['prescription_date'] as DateTime?,
      );
    }).toList();
  }

  Future<List<AppointmentRequestItem>> getAppointmentRequests(
    Session session, {
    String? status,
    String? query,
    int limit = 100,
    int offset = 0,
  }) async {
    final resolvedDoctorId = requireAuthenticatedUserId(session);
    await _ensureAppointmentTables(session);

    final normalizedStatus = (status ?? '').trim().toUpperCase();
    final validStatus = normalizedStatus == 'PENDING' ||
            normalizedStatus == 'CONFIRMED' ||
            normalizedStatus == 'DECLINED'
        ? normalizedStatus
        : '';
    final q = (query ?? '').trim();

    final rows = await session.db.unsafeQuery(
      r'''
      SELECT
        ar.request_id,
        ar.patient_id,
        ar.doctor_id,
        COALESCE(u.name, '') AS patient_name,
        COALESCE(u.phone, '') AS patient_phone,
        ar.appointment_date,
        to_char(ar.appointment_time, 'HH24:MI') AS appointment_time,
        ar.reason,
        ar.notes,
        ar.mode,
        ar.is_urgent,
        ar.status,
        ar.decline_reason,
        ar.created_at,
        ar.acted_at
      FROM appointment_requests ar
      JOIN users u ON u.user_id = ar.patient_id
      WHERE ar.doctor_id = @did
        AND (@status = '' OR ar.status = @status)
        AND (
          @q = '' OR
          LOWER(u.name) LIKE LOWER(@likeQ) OR
          LOWER(ar.reason) LIKE LOWER(@likeQ) OR
          REPLACE(REPLACE(COALESCE(u.phone, ''), ' ', ''), '-', '') LIKE @phoneLike
        )
      ORDER BY ar.appointment_date ASC, ar.appointment_time ASC, ar.request_id DESC
      LIMIT @limit OFFSET @offset
      ''',
      parameters: QueryParameters.named({
        'did': resolvedDoctorId,
        'status': validStatus,
        'q': q,
        'likeQ': '%$q%',
        'phoneLike': '%${q.replaceAll(RegExp(r'[^0-9]'), '')}%',
        'limit': limit,
        'offset': offset,
      }),
    );

    return rows.map((r) {
      final m = r.toColumnMap();
      return AppointmentRequestItem(
        appointmentRequestId: m['request_id'] as int,
        patientId: m['patient_id'] as int,
        doctorId: m['doctor_id'] as int,
        patientName: _s(m['patient_name']),
        patientPhone: _s(m['patient_phone']),
        appointmentDate: m['appointment_date'] as DateTime,
        appointmentTime: _s(m['appointment_time']),
        reason: _s(m['reason']),
        notes: m['notes']?.toString(),
        mode: _s(m['mode']).isEmpty ? 'In-Person' : _s(m['mode']),
        urgent: m['is_urgent'] as bool? ?? false,
        status: _s(m['status']),
        declineReason: m['decline_reason']?.toString(),
        createdAt: m['created_at'] as DateTime? ?? DateTime.now(),
        actedAt: m['acted_at'] as DateTime?,
      );
    }).toList();
  }

  Future<bool> updateAppointmentRequestStatus(
    Session session, {
    required int appointmentRequestId,
    required String status,
    String? declineReason,
  }) async {
    final resolvedDoctorId = requireAuthenticatedUserId(session);
    await _ensureAppointmentTables(session);

    final normalizedStatus = status.trim().toUpperCase();
    if (normalizedStatus != 'CONFIRMED' && normalizedStatus != 'DECLINED') {
      throw Exception('Invalid status. Use CONFIRMED or DECLINED.');
    }

    final updatedRows = await session.db.unsafeQuery(
      '''
      UPDATE appointment_requests
      SET
        status = @status,
        decline_reason = CASE WHEN @status = 'DECLINED' THEN @declineReason ELSE NULL END,
        updated_at = NOW(),
        acted_at = NOW()
      WHERE request_id = @id
        AND doctor_id = @did
        AND status = 'PENDING'
      RETURNING patient_id, appointment_date, appointment_time, status, decline_reason
      ''',
      parameters: QueryParameters.named({
        'status': normalizedStatus,
        'declineReason': declineReason?.trim().isEmpty == true
            ? null
            : declineReason?.trim(),
        'id': appointmentRequestId,
        'did': resolvedDoctorId,
      }),
    );

    if (updatedRows.isEmpty) return false;

    try {
      final row = updatedRows.first.toColumnMap();
      final patientId = row['patient_id'] as int?;
      final apptDate = row['appointment_date'] as DateTime?;
      final apptTime = row['appointment_time']?.toString() ?? '';
      final statusText = (row['status']?.toString() ?? '').toUpperCase();
      final declineText = row['decline_reason']?.toString();

      if (patientId != null) {
        final title = statusText == 'CONFIRMED'
            ? 'Appointment Confirmed'
            : 'Appointment Declined';
        final message = statusText == 'CONFIRMED'
            ? 'Your appointment (ID: $appointmentRequestId) is confirmed for ${apptDate?.toIso8601String().split('T').first ?? '-'} at $apptTime.'
            : 'Your appointment (ID: $appointmentRequestId) was declined.${(declineText != null && declineText.trim().isNotEmpty) ? ' Reason: $declineText' : ''}';

        await session.db.unsafeExecute(
          '''
          INSERT INTO notifications (user_id, title, message, is_read, created_at)
          VALUES (@uid, @title, @message, FALSE, NOW())
          ''',
          parameters: QueryParameters.named({
            'uid': patientId,
            'title': title,
            'message': message,
          }),
        );
      }
    } catch (notifyError, notifyStack) {
      session.log(
        'updateAppointmentRequestStatus notification failed: $notifyError',
        level: LogLevel.warning,
        stackTrace: notifyStack,
      );
    }

    return true;
  }

  /// Bottom sheet: single prescription full details + medicines
  Future<PatientPrescriptionDetails?> getPrescriptionDetails(
    Session session, {
    required int prescriptionId,
  }) async {
    final resolvedDoctorId = requireAuthenticatedUserId(session);
    final presRows = await session.db.unsafeQuery(r'''
      SELECT
        prescription_id,
        name,
        mobile_number,
        gender,
        age,
        cc,
        oe,
        bp,
        temperature,
        advice,
        test
      FROM prescriptions
      WHERE prescription_id = @id AND doctor_id = @did
      LIMIT 1
    ''',
        parameters: QueryParameters.named({
          'id': prescriptionId,
          'did': resolvedDoctorId,
        }));

    if (presRows.isEmpty) return null;

    final p = presRows.first.toColumnMap();

    final itemRows = await session.db.unsafeQuery(r'''
      SELECT medicine_name, dosage_times, meal_timing, duration
      FROM prescribed_items
      WHERE prescription_id = @id
      ORDER BY item_id ASC
    ''', parameters: QueryParameters.named({'id': prescriptionId}));

    final items = itemRows.map((r) {
      final m = r.toColumnMap();
      return PatientPrescribedItem(
        medicineName: _s(m['medicine_name']),
        dosageTimes: _s(m['dosage_times']),
        mealTiming: _s(m['meal_timing']),
        duration: m['duration'] as int?,
      );
    }).toList();

    return PatientPrescriptionDetails(
      prescriptionId: p['prescription_id'] as int,
      name: _s(p['name']),
      mobileNumber: p['mobile_number']?.toString(),
      gender: p['gender']?.toString(),
      age: p['age'] as int?,
      cc: p['cc']?.toString(),
      oe: p['oe']?.toString(),
      bp: p['bp']?.toString(),
      temperature: p['temperature']?.toString(),
      advice: p['advice']?.toString(),
      test: p['test']?.toString(),
      items: items,
    );
  }

  String _decode(dynamic v) {
    if (v == null) return '';
    if (v is List<int>) return String.fromCharCodes(v);
    return v.toString();
  }

  String _s(dynamic v) {
    if (v == null) return '';
    if (v is List<int>) return String.fromCharCodes(v);
    return v.toString();
  }

  String _timeAgo(DateTime? createdAtUtc, DateTime nowUtc) {
    if (createdAtUtc == null) return '';
    final diff = nowUtc.difference(createdAtUtc);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}

import 'package:serverpod/serverpod.dart';
import 'package:backend_server/src/generated/protocol.dart';

import '../utils/auth_user.dart';

class PatientEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

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

  Future<void> _ensurePaymentColumns(Session session) async {
    await session.db.unsafeExecute('''
      ALTER TABLE test_results
      ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'PENDING';
    ''');
    await session.db.unsafeExecute('''
      ALTER TABLE test_results
      ADD COLUMN IF NOT EXISTS payment_method TEXT;
    ''');
    await session.db.unsafeExecute('''
      ALTER TABLE test_results
      ADD COLUMN IF NOT EXISTS transaction_id TEXT;
    ''');
    await session.db.unsafeExecute('''
      ALTER TABLE test_results
      ADD COLUMN IF NOT EXISTS paid_at TIMESTAMP;
    ''');
    await session.db.unsafeExecute('''
      ALTER TABLE test_results
      ADD COLUMN IF NOT EXISTS patient_notified_at TIMESTAMP;
    ''');
  }

  String _normalizePaymentMethod(String raw) {
    final value = raw.trim().toUpperCase();
    switch (value) {
      case 'BKASH':
        return 'BKASH';
      case 'NAGAD':
        return 'NAGAD';
      case 'ROCKET':
        return 'ROCKET';
      case 'VISA':
      case 'VISA CARD':
        return 'VISA';
      default:
        return 'BKASH';
    }
  }

  String _paymentTxnPrefix(String method) {
    switch (method) {
      case 'BKASH':
        return 'BK';
      case 'NAGAD':
        return 'NG';
      case 'ROCKET':
        return 'RK';
      case 'VISA':
        return 'VS';
      default:
        return 'BK';
    }
  }

  LabPaymentItem _mapLabPaymentItem(Map<String, dynamic> m) {
    return LabPaymentItem(
      resultId: m['result_id'] as int,
      testId: m['test_id'] as int,
      serialNo: 'LAB-${(m['result_id'] as int).toString().padLeft(4, '0')}',
      patientName: _safeString(m['patient_name']).trim().isEmpty
          ? 'Unknown Patient'
          : _safeString(m['patient_name']),
      mobileNumber: _safeString(m['mobile_number']),
      patientType: _safeString(m['patient_type']).trim().isEmpty
          ? 'STUDENT'
          : _safeString(m['patient_type']).toUpperCase(),
      testName: _safeString(m['test_name']),
      amount: _toDouble(m['amount']),
      createdAt: (m['created_at'] as DateTime?) ?? DateTime.now(),
      isUploaded: _toBool(m['is_uploaded']),
      submittedAt: m['submitted_at'] as DateTime?,
      paymentStatus: _safeString(m['payment_status']).trim().isEmpty
          ? 'PENDING'
          : _safeString(m['payment_status']).toUpperCase(),
      paymentMethod: m['payment_method'] as String?,
      transactionId: m['transaction_id'] as String?,
      paidAt: m['paid_at'] as DateTime?,
      patientNotifiedAt: m['patient_notified_at'] as DateTime?,
    );
  }

  DateTime? _safeDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is List<int>) {
      return DateTime.tryParse(String.fromCharCodes(value));
    }
    return DateTime.tryParse(value.toString());
  }

  // Fetch patient profile
  Future<PatientProfile?> getPatientProfile(Session session) async {
    try {
      final resolvedUserId = requireAuthenticatedUserId(session);

      final result = await session.db.unsafeQuery(
        '''
      SELECT 
        u.name,
        u.email,
        u.phone,
        u.profile_picture_url,
        p.blood_group,
        p.date_of_birth,
        p.gender
      FROM users u
      LEFT JOIN patient_profiles p
        ON p.user_id = u.user_id
      WHERE u.user_id = @userId
      ''',
        parameters: QueryParameters.named({'userId': resolvedUserId}),
      );

      if (result.isEmpty) return null;

      final row = result.first.toColumnMap();

      return PatientProfile(
        name: _safeString(row['name']),
        email: _safeString(row['email']),
        phone: _safeString(row['phone']),
        bloodGroup: row['blood_group']?.toString(),
        dateOfBirth: _safeDateTime(row['date_of_birth']),
        gender: row['gender']?.toString(),
        profilePictureUrl: row['profile_picture_url']?.toString(),
      );
    } catch (e, stack) {
      session.log(
        'Error getting patient profile: $e',
        level: LogLevel.error,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// List lab tests from the `tests` table. Returns a list of maps with keys:
  /// test_name, description, student_fee, teacher_fee, outside_fee, available
  Future<List<LabTests>> listTests(Session session) async {
    try {
      final result = await session.db.unsafeQuery(
        '''
        SELECT test_name, description, student_fee, teacher_fee, outside_fee, available
        FROM lab_tests
        ORDER BY test_name
        ''',
      );

      session.log('listTests: DB returned ${result.length} rows',
          level: LogLevel.info);

      // Map each row to a simple Map<String, dynamic>

      return result.map((r) {
        final row = r.toColumnMap();
        return LabTests(
          id: null, // backend will replace this
          testName: _safeString(row['test_name']),
          description: _safeString(row['description']),
          studentFee: _toDouble(row['student_fee']),
          teacherFee: _toDouble(row['teacher_fee']),
          outsideFee: _toDouble(row['outside_fee']),
          available: _toBool(row['available']),
        );
      }).toList();
    } catch (e, stack) {
      session.log('Error listing tests: $e\n$stack', level: LogLevel.error);
      return [];
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    if (v is List<int>) return double.tryParse(String.fromCharCodes(v)) ?? 0.0;
    return 0.0;
  }

  bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = _safeString(v).toLowerCase();
    return s == 't' || s == 'true' || s == '1';
  }

  /// Return the role of a user (stored as text in users.role) by email/userId.
  /// Returns uppercase role string or empty string if not found.
  Future<String> getUserRole(Session session) async {
    try {
      final resolvedUserId = requireAuthenticatedUserId(session);
      final result = await session.db.unsafeQuery(
        '''
        SELECT role::text as role FROM users WHERE user_id= @userId LIMIT 1
        ''',
        parameters: QueryParameters.named({'userId': resolvedUserId}),
      );

      if (result.isEmpty) return '';
      final row = result.first.toColumnMap();
      final roleVal = _safeString(row['role']).toUpperCase();
      return roleVal;
    } catch (e, stack) {
      session.log('Error fetching user role: $e\n$stack',
          level: LogLevel.error);
      return '';
    }
  }

  Future<int> createAppointmentRequest(
    Session session, {
    required int doctorId,
    required DateTime appointmentDate,
    required String appointmentTime,
    required String reason,
    String? notes,
    bool urgent = false,
    String mode = 'In-Person',
  }) async {
    try {
      final patientId = requireAuthenticatedUserId(session);
      await _ensureAppointmentTables(session);

      final normalizedTime = appointmentTime.trim();
      if (!RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(normalizedTime)) {
        throw Exception(
            'Invalid appointment time format. Expected HH:mm or HH:mm:ss');
      }

      final normalizedMode = switch (mode.trim()) {
        'Video' => 'Video',
        'Phone' => 'Phone',
        _ => 'In-Person',
      };

      final doctorRows = await session.db.unsafeQuery(
        '''
        SELECT user_id
        FROM users
        WHERE user_id = @doctorId AND lower(role::text) = 'doctor' AND is_active = TRUE
        LIMIT 1
        ''',
        parameters: QueryParameters.named({'doctorId': doctorId}),
      );

      if (doctorRows.isEmpty) {
        throw Exception('Selected doctor not found.');
      }

      final result = await session.db.unsafeQuery(
        '''
        INSERT INTO appointment_requests (
          patient_id,
          doctor_id,
          appointment_date,
          appointment_time,
          reason,
          notes,
          mode,
          is_urgent,
          status,
          created_at,
          updated_at
        ) VALUES (
          @patientId,
          @doctorId,
          @appointmentDate,
          CAST(@appointmentTime AS time),
          @reason,
          @notes,
          @mode,
          @urgent,
          'PENDING',
          NOW(),
          NOW()
        )
        RETURNING request_id
        ''',
        parameters: QueryParameters.named({
          'patientId': patientId,
          'doctorId': doctorId,
          'appointmentDate': DateTime(
            appointmentDate.year,
            appointmentDate.month,
            appointmentDate.day,
          ),
          'appointmentTime': normalizedTime,
          'reason': reason.trim(),
          'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
          'mode': normalizedMode,
          'urgent': urgent,
        }),
      );

      if (result.isEmpty) return -1;
      final requestId = result.first.toColumnMap()['request_id'] as int;

      try {
        await session.db.unsafeExecute(
          '''
          INSERT INTO notifications (user_id, title, message, is_read, created_at)
          VALUES (
            @doctorId,
            'New Appointment Request',
            @message,
            FALSE,
            NOW()
          )
          ''',
          parameters: QueryParameters.named({
            'doctorId': doctorId,
            'message':
                'A patient requested an appointment on ${appointmentDate.toIso8601String().split('T').first} at $normalizedTime. Request ID: $requestId',
          }),
        );
      } catch (notifyError, notifyStack) {
        session.log(
          'createAppointmentRequest notification failed: $notifyError',
          level: LogLevel.warning,
          stackTrace: notifyStack,
        );
      }

      return requestId;
    } catch (e, stack) {
      session.log(
        'createAppointmentRequest failed: $e',
        level: LogLevel.error,
        stackTrace: stack,
      );
      return -1;
    }
  }

  Future<List<AppointmentRequestItem>> getMyAppointmentRequests(
    Session session,
  ) async {
    try {
      final patientId = requireAuthenticatedUserId(session);
      await _ensureAppointmentTables(session);

      final rows = await session.db.unsafeQuery(
        '''
        SELECT
          ar.request_id,
          ar.patient_id,
          ar.doctor_id,
          COALESCE(pu.name, '') AS patient_name,
          COALESCE(pu.phone, '') AS patient_phone,
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
        JOIN users pu ON pu.user_id = ar.patient_id
        WHERE ar.patient_id = @patientId
        ORDER BY ar.created_at DESC, ar.request_id DESC
        ''',
        parameters: QueryParameters.named({'patientId': patientId}),
      );

      return rows.map((r) {
        final m = r.toColumnMap();
        return AppointmentRequestItem(
          appointmentRequestId: m['request_id'] as int,
          patientId: m['patient_id'] as int,
          doctorId: m['doctor_id'] as int,
          patientName: _safeString(m['patient_name']),
          patientPhone: _safeString(m['patient_phone']),
          appointmentDate: m['appointment_date'] as DateTime,
          appointmentTime: _safeString(m['appointment_time']),
          reason: _safeString(m['reason']),
          notes: m['notes']?.toString(),
          mode: _safeString(m['mode']).isEmpty
              ? 'In-Person'
              : _safeString(m['mode']),
          urgent: m['is_urgent'] as bool? ?? false,
          status: _safeString(m['status']),
          declineReason: m['decline_reason']?.toString(),
          createdAt: m['created_at'] as DateTime? ?? DateTime.now(),
          actedAt: m['acted_at'] as DateTime?,
        );
      }).toList();
    } catch (e, stack) {
      session.log(
        'getMyAppointmentRequests failed: $e',
        level: LogLevel.error,
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<bool> cancelMyAppointmentRequest(
    Session session, {
    required int appointmentRequestId,
    String? reason,
  }) async {
    try {
      final patientId = requireAuthenticatedUserId(session);
      await _ensureAppointmentTables(session);

      final cancellationReason = (reason ?? '').trim().isEmpty
          ? 'Cancelled by patient'
          : reason!.trim();

      final updated = await session.db.unsafeExecute(
        '''
        UPDATE appointment_requests
        SET
          status = 'DECLINED',
          decline_reason = @reason,
          updated_at = NOW(),
          acted_at = NOW()
        WHERE request_id = @id
          AND patient_id = @patientId
          AND status IN ('PENDING', 'CONFIRMED')
        ''',
        parameters: QueryParameters.named({
          'id': appointmentRequestId,
          'patientId': patientId,
          'reason': cancellationReason,
        }),
      );

      return updated > 0;
    } catch (e, stack) {
      session.log(
        'cancelMyAppointmentRequest failed: $e',
        level: LogLevel.error,
        stackTrace: stack,
      );
      return false;
    }
  }

  Future<bool> rescheduleMyAppointmentRequest(
    Session session, {
    required int appointmentRequestId,
    required DateTime appointmentDate,
    required String appointmentTime,
    String? notes,
  }) async {
    try {
      final patientId = requireAuthenticatedUserId(session);
      await _ensureAppointmentTables(session);

      final normalizedTime = appointmentTime.trim();
      if (!RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(normalizedTime)) {
        throw Exception(
          'Invalid appointment time format. Expected HH:mm or HH:mm:ss',
        );
      }

      final updated = await session.db.unsafeExecute(
        '''
        UPDATE appointment_requests
        SET
          appointment_date = @appointmentDate,
          appointment_time = CAST(@appointmentTime AS time),
          notes = COALESCE(@notes, notes),
          status = 'PENDING',
          decline_reason = NULL,
          updated_at = NOW(),
          acted_at = NULL
        WHERE request_id = @id
          AND patient_id = @patientId
          AND status IN ('PENDING', 'CONFIRMED')
        ''',
        parameters: QueryParameters.named({
          'id': appointmentRequestId,
          'patientId': patientId,
          'appointmentDate': DateTime(
            appointmentDate.year,
            appointmentDate.month,
            appointmentDate.day,
          ),
          'appointmentTime': normalizedTime,
          'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        }),
      );

      return updated > 0;
    } catch (e, stack) {
      session.log(
        'rescheduleMyAppointmentRequest failed: $e',
        level: LogLevel.error,
        stackTrace: stack,
      );
      return false;
    }
  }

// 2. Update Patient Profile
  Future<String> updatePatientProfile(
    Session session,
    String name,
    String phone,
    String? bloodGroup,
    DateTime? dateOfBirth,
    String? gender,
    String? profileImageUrl,
  ) async {
    try {
      final resolvedUserId = requireAuthenticatedUserId(session);
      final rawImageInput = profileImageUrl?.trim();
      String? normalizeRemoteUrl(String? value) {
        final raw = value?.trim();
        if (raw == null || raw.isEmpty) return null;

        final parsed = Uri.tryParse(raw);
        if (parsed != null &&
            (parsed.scheme == 'http' || parsed.scheme == 'https') &&
            parsed.host.isNotEmpty) {
          return raw;
        }

        // Accept protocol-relative URLs like //res.cloudinary.com/...
        if (raw.startsWith('//')) {
          return 'https:$raw';
        }

        // Accept bare host URLs and normalize to https.
        if (parsed != null &&
            parsed.scheme.isEmpty &&
            parsed.host.isEmpty &&
            raw.contains('.')) {
          return 'https://$raw';
        }

        return null;
      }

      final normalizedImageUrl = normalizeRemoteUrl(profileImageUrl);

      if (rawImageInput != null &&
          rawImageInput.isNotEmpty &&
          normalizedImageUrl == null) {
        session.log(
          'updatePatientProfile: rejected invalid profile image URL for user_id=$resolvedUserId value="$rawImageInput"',
          level: LogLevel.warning,
        );
        return 'Invalid profile image URL';
      }

      return await session.db.transaction((transaction) async {
        final updatedUsers = await session.db.unsafeExecute(
          '''
        UPDATE users
        SET name = @name,
            phone = @phone,
            profile_picture_url = CASE
              WHEN @url IS NULL THEN profile_picture_url
              ELSE @url
            END
        WHERE user_id = @id
        ''',
          parameters: QueryParameters.named({
            'id': resolvedUserId,
            'name': name,
            'phone': phone,
            'url': normalizedImageUrl,
          }),
        );

        if (updatedUsers <= 0) {
          session.log(
            'updatePatientProfile: no users row updated for user_id=$resolvedUserId',
            level: LogLevel.warning,
          );
          return 'Failed to update profile';
        }

        if (normalizedImageUrl != null) {
          final verifyRows = await session.db.unsafeQuery(
            '''
            SELECT profile_picture_url
            FROM users
            WHERE user_id = @id
            LIMIT 1
            ''',
            parameters: QueryParameters.named({'id': resolvedUserId}),
          );

          if (verifyRows.isEmpty) {
            session.log(
              'updatePatientProfile: verification read returned no row for user_id=$resolvedUserId',
              level: LogLevel.warning,
            );
            return 'Failed to verify profile update';
          }

          final savedUrl = verifyRows.first
              .toColumnMap()['profile_picture_url']
              ?.toString()
              .trim();

          if (savedUrl == null || savedUrl != normalizedImageUrl) {
            session.log(
              'updatePatientProfile: profile_picture_url mismatch for user_id=$resolvedUserId expected="$normalizedImageUrl" actual="$savedUrl"',
              level: LogLevel.warning,
            );
            return 'Failed to persist profile picture URL';
          }
        }

        await session.db.unsafeExecute(
          '''
        INSERT INTO patient_profiles
          (user_id, blood_group, date_of_birth, gender)
        VALUES
          (@id, NULLIF(@bg, ''), @dob, @gender)
        ON CONFLICT (user_id)
        DO UPDATE SET
          blood_group = COALESCE(EXCLUDED.blood_group, patient_profiles.blood_group),
          date_of_birth = EXCLUDED.date_of_birth,
          gender = COALESCE(EXCLUDED.gender, patient_profiles.gender)
        ''',
          parameters: QueryParameters.named({
            'id': resolvedUserId,
            'bg': bloodGroup,
            'dob': dateOfBirth,
            'gender': gender,
          }),
        );

        return 'Profile updated successfully';
      });
    } catch (e, stack) {
      session.log(
        'Update profile failed: $e',
        level: LogLevel.error,
        stackTrace: stack,
      );
      return 'Failed to update profile: $e';
    }
  }

  /// Fetch logged-in patient's lab reports using phone number
  Future<List<PatientReportDto>> getMyLabReports(
    Session session,
  ) async {
    try {
      final resolvedUserId = requireAuthenticatedUserId(session);
      final result = await session.db.unsafeQuery(
        '''
      SELECT * FROM (
        SELECT 
          tr.result_id::int AS result_id,
          COALESCE(lt.test_name, 'Lab Test')::text AS test_name,
          COALESCE(tr.created_at, NOW()) AS created_at,
          COALESCE(tr.is_uploaded, FALSE) AS is_uploaded,
          tr.attachment_path::text AS attachment_path,
          NULL::text AS doctor_notes,
          NULL::text AS review_action
        FROM users u
        JOIN test_results tr 
          ON tr.mobile_number = u.phone
        LEFT JOIN lab_tests lt 
          ON lt.test_id = tr.test_id
        WHERE u.user_id = @userId

        UNION ALL

        SELECT
          (1000000 + r.report_id)::int AS result_id,
          COALESCE(NULLIF(r.type, ''), 'Reviewed Lab Report')::text AS test_name,
          COALESCE(r.created_at, r.report_date::timestamp, NOW()) AS created_at,
          (r.reviewed = TRUE AND COALESCE(r.file_path, '') <> '') AS is_uploaded,
          r.file_path::text AS attachment_path,
          CASE WHEN r.visible_to_patient = TRUE THEN r.doctor_notes ELSE NULL END AS doctor_notes,
          CASE WHEN r.visible_to_patient = TRUE THEN r.review_action ELSE NULL END AS review_action
        FROM "UploadpatientR" r
        WHERE r.patient_id = @userId
          AND r.reviewed = TRUE
      ) mixed_reports
      ORDER BY created_at DESC, result_id DESC
      ''',
        parameters: QueryParameters.named({'userId': resolvedUserId}),
      );

      return result.map((r) {
        final row = r.toColumnMap();
        return PatientReportDto(
          id: row['result_id'] as int,
          testName: _safeString(row['test_name']),
          date: row['created_at'] as DateTime,
          isUploaded: _toBool(row['is_uploaded']),
          fileUrl: _safeString(row['attachment_path']),
          doctorNotes: row['doctor_notes'] as String?,
          reviewAction: row['review_action'] as String?,
        );
      }).toList();
    } catch (e, stack) {
      session.log(
        'Error fetching lab reports: $e',
        level: LogLevel.error,
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<List<LabPaymentItem>> getMyLabPaymentItems(Session session) async {
    try {
      await _ensurePaymentColumns(session);
      final resolvedUserId = requireAuthenticatedUserId(session);
      final rows = await session.db.unsafeQuery(
        '''
        SELECT
          tr.result_id,
          tr.test_id,
          COALESCE(tr.patient_name, 'Unknown Patient') AS patient_name,
          COALESCE(tr.mobile_number, '') AS mobile_number,
          COALESCE(tr.patient_type, 'STUDENT') AS patient_type,
          COALESCE(lt.test_name, 'Test ' || tr.test_id::text) AS test_name,
          COALESCE(tr.created_at, NOW()) AS created_at,
          COALESCE(tr.is_uploaded, FALSE) AS is_uploaded,
          tr.submitted_at,
          COALESCE(tr.payment_status, 'PENDING') AS payment_status,
          tr.payment_method,
          tr.transaction_id,
          tr.paid_at,
          tr.patient_notified_at,
          CASE
            WHEN UPPER(COALESCE(tr.patient_type, 'STUDENT')) IN ('STAFF', 'TEACHER') THEN COALESCE(lt.teacher_fee, 0)
            WHEN UPPER(COALESCE(tr.patient_type, 'STUDENT')) = 'OUTSIDE' THEN COALESCE(lt.outside_fee, 0)
            ELSE COALESCE(lt.student_fee, 0)
          END AS amount
        FROM users u
        JOIN test_results tr ON tr.mobile_number = u.phone
        LEFT JOIN lab_tests lt ON lt.test_id = tr.test_id
        WHERE u.user_id = @userId
        ORDER BY COALESCE(tr.created_at, NOW()) DESC, tr.result_id DESC
        ''',
        parameters: QueryParameters.named({'userId': resolvedUserId}),
      );

      return rows.map((r) => _mapLabPaymentItem(r.toColumnMap())).toList();
    } catch (e, stack) {
      session.log('Error fetching lab payment items: $e',
          level: LogLevel.error, stackTrace: stack);
      return [];
    }
  }

  Future<LabPaymentItem?> payMyLabBill(
    Session session, {
    required int resultId,
    required String paymentMethod,
  }) async {
    try {
      await _ensurePaymentColumns(session);
      final resolvedUserId = requireAuthenticatedUserId(session);
      final ownership = await session.db.unsafeQuery(
        '''
        SELECT tr.result_id
        FROM users u
        JOIN test_results tr ON tr.mobile_number = u.phone
        WHERE u.user_id = @userId AND tr.result_id = @id
        LIMIT 1
        ''',
        parameters:
            QueryParameters.named({'userId': resolvedUserId, 'id': resultId}),
      );
      if (ownership.isEmpty) return null;

      final method = _normalizePaymentMethod(paymentMethod);
      final now = DateTime.now();
      final txn =
          '${_paymentTxnPrefix(method)}-$resultId-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

      await session.db.unsafeExecute(
        '''
        UPDATE test_results
        SET payment_status = 'PAID',
            payment_method = @method,
            transaction_id = COALESCE(transaction_id, @txn),
            paid_at = COALESCE(paid_at, NOW())
        WHERE result_id = @id
        ''',
        parameters: QueryParameters.named({
          'id': resultId,
          'method': method,
          'txn': txn,
        }),
      );

      await session.db.unsafeExecute(
        '''
        INSERT INTO notifications (user_id, title, message, is_read, created_at)
        VALUES (
          @uid,
          'Payment Updated',
          @message,
          FALSE,
          NOW()
        )
        ''',
        parameters: QueryParameters.named({
          'uid': resolvedUserId,
          'message':
              'Payment completed for lab result #$resultId via $method. Transaction is being processed.',
        }),
      );

      final rows = await session.db.unsafeQuery(
        '''
        SELECT
          tr.result_id,
          tr.test_id,
          COALESCE(tr.patient_name, 'Unknown Patient') AS patient_name,
          COALESCE(tr.mobile_number, '') AS mobile_number,
          COALESCE(tr.patient_type, 'STUDENT') AS patient_type,
          COALESCE(lt.test_name, 'Test ' || tr.test_id::text) AS test_name,
          COALESCE(tr.created_at, NOW()) AS created_at,
          COALESCE(tr.is_uploaded, FALSE) AS is_uploaded,
          tr.submitted_at,
          COALESCE(tr.payment_status, 'PENDING') AS payment_status,
          tr.payment_method,
          tr.transaction_id,
          tr.paid_at,
          tr.patient_notified_at,
          CASE
            WHEN UPPER(COALESCE(tr.patient_type, 'STUDENT')) IN ('STAFF', 'TEACHER') THEN COALESCE(lt.teacher_fee, 0)
            WHEN UPPER(COALESCE(tr.patient_type, 'STUDENT')) = 'OUTSIDE' THEN COALESCE(lt.outside_fee, 0)
            ELSE COALESCE(lt.student_fee, 0)
          END AS amount
        FROM test_results tr
        LEFT JOIN lab_tests lt ON lt.test_id = tr.test_id
        WHERE tr.result_id = @id
        LIMIT 1
        ''',
        parameters: QueryParameters.named({'id': resultId}),
      );

      if (rows.isEmpty) return null;
      return _mapLabPaymentItem(rows.first.toColumnMap());
    } catch (e, stack) {
      session.log('Error paying lab bill: $e',
          level: LogLevel.error, stackTrace: stack);
      return null;
    }
  }

// ১. ড্রপডাউনে দেখানোর জন্য রোগীর আগের প্রেসক্রিপশন লিস্ট আনা
  Future<List<PrescriptionList>> getMyPrescriptionList(Session session) async {
    final resolvedUserId = requireAuthenticatedUserId(session);
    final query = '''
      SELECT
        p.prescription_id,
        p.prescription_date,
        u.name as doctor_name,
        p.revised_from_id AS revised_from_prescription_id,
        (
          SELECT r.report_id
          FROM "UploadpatientR" r
          WHERE r.patient_id = p.patient_id
            AND p.revised_from_id IS NOT NULL
            AND r.prescription_id = p.revised_from_id
          ORDER BY r.created_at DESC
          LIMIT 1
        ) AS source_report_id,
        (
          SELECT r.type
          FROM "UploadpatientR" r
          WHERE r.patient_id = p.patient_id
            AND p.revised_from_id IS NOT NULL
            AND r.prescription_id = p.revised_from_id
          ORDER BY r.created_at DESC
          LIMIT 1
        ) AS source_report_type,
        (
          SELECT r.created_at
          FROM "UploadpatientR" r
          WHERE r.patient_id = p.patient_id
            AND p.revised_from_id IS NOT NULL
            AND r.prescription_id = p.revised_from_id
          ORDER BY r.created_at DESC
          LIMIT 1
        ) AS source_report_created_at
      FROM prescriptions p
      JOIN users u ON p.doctor_id = u.user_id
      WHERE p.patient_id = @userId
      ORDER BY p.prescription_date DESC
      LIMIT 5;
    ''';

    final result = await session.db.unsafeQuery(
      query,
      parameters: QueryParameters.named({'userId': resolvedUserId}),
    );

    return result.map((r) {
      final map = r.toColumnMap();
      return PrescriptionList(
        prescriptionId: map['prescription_id'],
        date: map['prescription_date'] as DateTime,
        doctorName: _safeString(map['doctor_name']),
        revisedFromPrescriptionId: map['revised_from_prescription_id'] as int?,
        sourceReportId: map['source_report_id'] as int?,
        sourceReportType: map['source_report_type'] as String?,
        sourceReportCreatedAt: map['source_report_created_at'] as DateTime?,
      );
    }).toList();
  }

  // ২. ক্লাউডিনারি আপলোডসহ রিপোর্ট ডাটা সেভ এবং নোটিফিকেশন পাঠানো
  Future<bool> finalizeReportUpload(
    Session session, {
    required int prescriptionId,
    required String reportType,
    required String fileUrl,
  }) async {
    try {
      final int resolvedPatientId = requireAuthenticatedUserId(session);
      final normalizedType =
          reportType.trim().isEmpty ? 'Lab Report' : reportType.trim();

      final secureUrl = fileUrl.trim();
      if (!(secureUrl.startsWith('http://') ||
          secureUrl.startsWith('https://'))) {
        return false;
      }

      // Validate prescription ownership and resolve assigned doctor.
      final prescriptionRows = await session.db.unsafeQuery(
        '''
        SELECT patient_id, doctor_id
        FROM prescriptions
        WHERE prescription_id = @pId
        LIMIT 1
        ''',
        parameters: QueryParameters.named({'pId': prescriptionId}),
      );

      if (prescriptionRows.isEmpty) return false;
      final prescriptionMap = prescriptionRows.first.toColumnMap();
      final prescriptionPatientId = prescriptionMap['patient_id'] as int?;
      final doctorId = prescriptionMap['doctor_id'] as int?;
      if (prescriptionPatientId == null ||
          doctorId == null ||
          prescriptionPatientId != resolvedPatientId) {
        return false;
      }

      // ১২ ঘণ্টা রিপ্লেস লজিক: চেক করুন এই প্রেসক্রিপশনের জন্য কোনো রিপোর্ট অলরেডি আছে কি না
      final existing = await session.db.unsafeQuery(
        '''SELECT report_id, created_at FROM "UploadpatientR"
           WHERE patient_id = @pId AND prescription_id = @refId 
           ORDER BY created_at DESC LIMIT 1''',
        parameters: QueryParameters.named(
          {'pId': resolvedPatientId, 'refId': prescriptionId},
        ),
      );

      if (existing.isNotEmpty) {
        final row = existing.first.toColumnMap();
        final DateTime createdAt = row['created_at'];
        if (DateTime.now().difference(createdAt).inHours < 12) {
          // ১২ ঘণ্টার কম হলে আপডেট করুন
          final updated = await session.db.unsafeExecute(
            '''
            UPDATE "UploadpatientR"
            SET
              file_path = @path,
              type = @type,
              report_date = CURRENT_DATE,
              prescribed_doctor_id = @docId,
              uploaded_by = @uploadedBy,
              reviewed = FALSE
            WHERE report_id = @report_id
            ''',
            parameters: QueryParameters.named({
              'report_id': existing.first.toColumnMap()['report_id'],
              'path': secureUrl,
              'type': normalizedType,
              'docId': doctorId,
              'uploadedBy': resolvedPatientId,
            }),
          );

          if (updated <= 0) return false;

          await session.db.unsafeExecute('''
            INSERT INTO notifications (user_id, title, message, is_read, created_at)
            VALUES (@docId, 'Lab Report Updated', @message, false, NOW())
          ''',
              parameters: QueryParameters.named({
                'docId': doctorId,
                'message':
                    'A patient updated a ${normalizedType.toLowerCase()} for Prescription ID: $prescriptionId.',
              }));

          return true;
        }
      }

      final patientNameRows = await session.db.unsafeQuery(
        'SELECT name FROM users WHERE user_id = @uid LIMIT 1',
        parameters: QueryParameters.named({'uid': resolvedPatientId}),
      );
      final patientName = patientNameRows.isEmpty
          ? 'Patient #$resolvedPatientId'
          : _safeString(patientNameRows.first.toColumnMap()['name']);

      // ডাটাবেসে নতুন রিপোর্ট সেভ
      final insertRows = await session.db.unsafeQuery('''
        INSERT INTO "UploadpatientR"
        (patient_id, type, report_date, file_path, prescribed_doctor_id, prescription_id, uploaded_by, created_at)
        VALUES (@pId, @type, CURRENT_DATE, @path, @docId, @refId, @pId, NOW())
        RETURNING report_id
      ''',
          parameters: QueryParameters.named({
            'pId': resolvedPatientId,
            'type': normalizedType,
            'path': secureUrl,
            'docId': doctorId,
            'refId': prescriptionId,
          }));

      final insertedReportId = insertRows.isEmpty
          ? null
          : insertRows.first.toColumnMap()['report_id'] as int?;

      // ডাক্তারকে নোটিফিকেশন
      await session.db.unsafeExecute('''
        INSERT INTO notifications (user_id, title, message, is_read, created_at)
        VALUES (@docId, 'New Lab Report Received', @message, false, NOW())
      ''',
          parameters: QueryParameters.named({
            'docId': doctorId,
            'message':
                '$patientName uploaded a ${normalizedType.toLowerCase()} report.${insertedReportId == null ? '' : ' Report ID: $insertedReportId.'} Prescription ID: $prescriptionId.',
          }));

      return true;
    } catch (e, stackTrace) {
      session.log('Error: $e', level: LogLevel.error, stackTrace: stackTrace);
      return false;
    }
  }

  // আপনার আপলোড করা রিপোর্টগুলোর লিস্ট দেখার জন্য নতুন মেথড
  Future<List<PatientExternalReport>> getMyExternalReports(
      Session session) async {
    try {
      final resolvedUserId = requireAuthenticatedUserId(session);
      // এখানে আপনার টেবিলের নাম অনুযায়ী কুয়েরি হবে (ধরে নিচ্ছি 'upload_patient_reports')
      final result = await session.db.unsafeQuery(
        '''
        SELECT 
          report_id,
          patient_id, type, report_date, file_path, 
          prescribed_doctor_id, prescription_id, uploaded_by, reviewed, created_at
        FROM "UploadpatientR"
        WHERE patient_id = @userId
        ORDER BY created_at DESC
        ''',
        parameters: QueryParameters.named({'userId': resolvedUserId}),
      );

      return result.map((r) {
        final row = r.toColumnMap();
        return PatientExternalReport(
          reportId: row['report_id'] as int?,
          patientId: row['patient_id'],
          type: _safeString(row['type']),
          reportDate: row['report_date'] as DateTime,
          filePath: _safeString(row['file_path']),
          prescribedDoctorId: row['prescribed_doctor_id'],
          prescriptionId: row['prescription_id'],
          uploadedBy: row['uploaded_by'],
          reviewed: (row['reviewed'] as bool?) ?? false,
          createdAt: row['created_at'] as DateTime?,
        );
      }).toList();
    } catch (e, stack) {
      session.log('Error fetching external reports: $e',
          level: LogLevel.error, stackTrace: stack);
      return [];
    }
  }

  /// ১. রোগীর সব প্রেসক্রিপশনের লিস্ট আনা
  Future<List<PrescriptionList>> getPrescriptionList(
    Session session,
    int patientId,
  ) async {
    try {
      // এখানে 'prescription' টেবিল এবং 'users' টেবিল জয়েন করে ডাক্তারের নামসহ লিস্ট আনা হচ্ছে
      final rows = await session.db.unsafeQuery(
        '''
        SELECT
          p.prescription_id,
          p.prescription_date,
          u.name AS doctor_name,
          p.revised_from_id AS revised_from_prescription_id,
          (
            SELECT r.report_id
            FROM "UploadpatientR" r
            WHERE r.patient_id = p.patient_id
              AND p.revised_from_id IS NOT NULL
              AND r.prescription_id = p.revised_from_id
            ORDER BY r.created_at DESC
            LIMIT 1
          ) AS source_report_id,
          (
            SELECT r.type
            FROM "UploadpatientR" r
            WHERE r.patient_id = p.patient_id
              AND p.revised_from_id IS NOT NULL
              AND r.prescription_id = p.revised_from_id
            ORDER BY r.created_at DESC
            LIMIT 1
          ) AS source_report_type,
          (
            SELECT r.created_at
            FROM "UploadpatientR" r
            WHERE r.patient_id = p.patient_id
              AND p.revised_from_id IS NOT NULL
              AND r.prescription_id = p.revised_from_id
            ORDER BY r.created_at DESC
            LIMIT 1
          ) AS source_report_created_at
        FROM prescriptions p
        JOIN users u ON u.user_id = p.doctor_id
        WHERE p.patient_id = @pid
        ORDER BY p.prescription_date DESC
        ''',
        parameters: QueryParameters.named({'pid': patientId}),
      );

      return rows.map((r) {
        final map = r.toColumnMap();
        return PrescriptionList(
          prescriptionId: map['prescription_id'] as int,
          date: map['prescription_date'] as DateTime,
          doctorName: _safeString(map['doctor_name']),
          revisedFromPrescriptionId:
              map['revised_from_prescription_id'] as int?,
          sourceReportId: map['source_report_id'] as int?,
          sourceReportType: map['source_report_type'] as String?,
          sourceReportCreatedAt: map['source_report_created_at'] as DateTime?,
        );
      }).toList();
    } catch (e, stack) {
      session.log('Error fetching prescription list: $e',
          level: LogLevel.error, stackTrace: stack);
      return [];
    }
  }

  /// সরাসরি Patient ID (User ID) দিয়ে প্রেসক্রিপশন লিস্ট আনা
  Future<List<PrescriptionList>> getPrescriptionsByPatientId(
    Session session,
    int patientId,
  ) async {
    try {
      // db.sql onujayi table er nam 'prescriptions' (not 'prescription')
      // ebong kolyamer nam 'prescription_id'
      final rows = await session.db.unsafeQuery(
        '''
        SELECT 
          p.prescription_id, 
          p.prescription_date,
          u.name AS doctor_name,
          p.revised_from_id AS revised_from_prescription_id,
          (
            SELECT r.report_id
            FROM "UploadpatientR" r
            WHERE r.patient_id = p.patient_id
              AND p.revised_from_id IS NOT NULL
              AND r.prescription_id = p.revised_from_id
            ORDER BY r.created_at DESC
            LIMIT 1
          ) AS source_report_id,
          (
            SELECT r.type
            FROM "UploadpatientR" r
            WHERE r.patient_id = p.patient_id
              AND p.revised_from_id IS NOT NULL
              AND r.prescription_id = p.revised_from_id
            ORDER BY r.created_at DESC
            LIMIT 1
          ) AS source_report_type,
          (
            SELECT r.created_at
            FROM "UploadpatientR" r
            WHERE r.patient_id = p.patient_id
              AND p.revised_from_id IS NOT NULL
              AND r.prescription_id = p.revised_from_id
            ORDER BY r.created_at DESC
            LIMIT 1
          ) AS source_report_created_at
        FROM prescriptions p
        JOIN users u ON u.user_id = p.doctor_id
        WHERE p.patient_id = @pid
        ORDER BY p.prescription_date DESC
        ''',
        parameters: QueryParameters.named({'pid': patientId}),
      );

      return rows.map((r) {
        final map = r.toColumnMap();
        return PrescriptionList(
          prescriptionId: map['prescription_id'] as int,
          date: map['prescription_date'] as DateTime,
          doctorName: _safeString(map['doctor_name']),
          revisedFromPrescriptionId:
              map['revised_from_prescription_id'] as int?,
          sourceReportId: map['source_report_id'] as int?,
          sourceReportType: map['source_report_type'] as String?,
          sourceReportCreatedAt: map['source_report_created_at'] as DateTime?,
        );
      }).toList();
    } catch (e, stack) {
      session.log('Error: $e', level: LogLevel.error, stackTrace: stack);
      return [];
    }
  }
  // আপনার দেওয়া getPrescriptionDetail মেথডটি এর সাথেই থাকবে (PDF এর জন্য)

  /// ২. একটি নির্দিষ্ট প্রেসক্রিপশনের বিস্তারিত তথ্য (PDF এর জন্য)
  Future<PrescriptionDetail?> getPrescriptionDetail(
    Session session,
    int prescriptionId,
  ) async {
    try {
      // ---- 1. Fetch prescription and doctor info ----
      final presRows = await session.db.unsafeQuery(
        '''
      SELECT
        p.*,
        u.name AS doctor_name,
        s.signature_url
      FROM prescriptions p
      JOIN users u ON u.user_id = p.doctor_id
      LEFT JOIN staff_profiles s ON s.user_id = p.doctor_id
      WHERE p.prescription_id = @id
      ''',
        parameters: QueryParameters.named({'id': prescriptionId}),
      );

      if (presRows.isEmpty) return null;
      final p = presRows.first.toColumnMap();

      final prescription = Prescription(
        id: p['prescription_id'],
        patientId: p['patient_id'],
        doctorId: p['doctor_id'],
        name: _safeString(p['name']),
        age: p['age'],
        mobileNumber: _safeString(p['mobile_number']),
        gender: _safeString(p['gender']),
        prescriptionDate: p['prescription_date'],
        cc: _safeString(p['cc']),
        oe: _safeString(p['oe']),
        advice: _safeString(p['advice']),
        test: _safeString(p['test']),
        nextVisit: _safeString(p['next_visit']),
        isOutside: _toBool(p['is_outside']),
        createdAt: p['created_at'],
      );

      // ---- 2. Fetch prescribed items ----
      final itemRows = await session.db.unsafeQuery(
        '''
      SELECT *
      FROM prescribed_items
      WHERE prescription_id = @pid
      ORDER BY item_id
      ''',
        parameters: QueryParameters.named({'pid': prescriptionId}),
      );

      final items = itemRows.map((i) {
        final row = i.toColumnMap();
        return PrescribedItem(
          id: row['item_id'],
          prescriptionId: row['prescription_id'],
          medicineName: _safeString(row['medicine_name']),
          dosageTimes: _safeString(row['dosage_times']),
          mealTiming: _safeString(row['meal_timing']),
          duration: row['duration'],
        );
      }).toList();

      // ---- 3. Return complete PrescriptionDetail ----
      return PrescriptionDetail(
        prescription: prescription,
        items: items,
        doctorName: _safeString(p['doctor_name']),
        doctorSignatureUrl: _safeString(p['signature_url']),
      );
    } catch (e, stack) {
      session.log('Error fetching prescription detail: $e',
          level: LogLevel.error, stackTrace: stack);
      return null;
    }
  }

  /// Fetch all active medical staff (Admin, Doctor, Dispenser, Labstaff)
  /// Fetch all active medical staff (Admin, Doctor, Dispenser, Labstaff)
  Future<List<StaffInfo>> getMedicalStaff(Session session) async {
    try {
      final results = await session.db.unsafeQuery('''
      SELECT 
        u.user_id,
        u.name,
        u.phone,
        u.profile_picture_url,
        s.designation,
        s.qualification
      FROM users u
      LEFT JOIN staff_profiles s
        ON u.user_id = s.user_id
      WHERE lower(u.role::text) IN ('admin', 'doctor', 'dispenser', 'labstaff', 'lab')
        AND u.is_active = TRUE
      ORDER BY u.role, u.name;
      ''');

      return results.map((row) {
        final map = row.toColumnMap();

        return StaffInfo(
          userId: map['user_id'] as int?,
          name: map['name']?.toString() ?? '',
          phone: map['phone']?.toString() ?? '',
          designation: map['designation']?.toString(),
          profilePictureUrl: map['profile_picture_url']?.toString(),
          qualification: map['qualification']?.toString(),
        );
      }).toList();
    } catch (e, stack) {
      session.log(
        'Error fetching medical staff: $e',
        level: LogLevel.error,
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<List<AmbulanceContact>> getAmbulanceContacts(Session session) async {
    try {
      final result = await session.db.unsafeQuery('''
      SELECT
        id,
        title,
        phone_bn || ' || ' || phone_en AS phone_combined,
        is_primary
      FROM ambulance_contact
      WHERE is_active = true
      ORDER BY is_primary DESC, id ASC
      ''');

      return result.map((row) {
        final map = row.toColumnMap();
        final phoneCombined = (map['phone_combined'] as String).split(' || ');
        final phoneBn = phoneCombined.isNotEmpty ? phoneCombined[0] : '';
        final phoneEn = phoneCombined.length > 1 ? phoneCombined[1] : '';

        return AmbulanceContact(
          contactId: map['id'] as int,
          contactTitle: map['title'] as String,
          phoneBn: phoneBn,
          phoneEn: phoneEn,
          isPrimary: map['is_primary'] as bool? ?? false,
        );
      }).toList();
    } catch (e, stack) {
      session.log('Error fetching ambulance contacts: $e',
          level: LogLevel.error, stackTrace: stack);
      return [];
    }
  }

  String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List<int>) return String.fromCharCodes(value);
    return value.toString();
  }

  Future<List<OndutyStaff>> getOndutyStaff(
    Session session,
  ) async {
    try {
      final result = await session.db.unsafeQuery(
        '''
      SELECT
        staff_id,
        staff_name,
        staff_role::text AS staff_role,
        shift_date,
        shift::text AS shift
      FROM staff_roster
      WHERE is_deleted = FALSE
      ORDER BY shift_date DESC, shift, staff_role, staff_name
      ''',
      );

      return result.map((r) {
        final row = r.toColumnMap();
        return OndutyStaff(
          staffId: row['staff_id'] as int,
          staffName: row['staff_name']?.toString() ?? '',
          staffRole: RosterUserRole.values.firstWhere(
            (e) =>
                e.name == (row['staff_role']?.toString().toUpperCase() ?? ''),
            orElse: () => RosterUserRole.STAFF,
          ),
          shiftDate: row['shift_date'] as DateTime,
          shift: ShiftType.values.firstWhere(
            (e) => e.name == (row['shift']?.toString().toUpperCase() ?? ''),
            orElse: () => ShiftType.MORNING,
          ),
        );
      }).toList();
    } catch (e, st) {
      session.log('getOndutyStaff failed: $e',
          level: LogLevel.error, stackTrace: st);
      return [];
    }
  }
}

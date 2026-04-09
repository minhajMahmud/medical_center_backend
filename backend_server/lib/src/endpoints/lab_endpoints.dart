import 'package:serverpod/serverpod.dart';
import 'package:backend_server/src/generated/protocol.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../utils/auth_user.dart';

class LabEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<void> _mirrorUploadedResultToDoctorReports(
    Session session, {
    required int resultId,
    int? uploadedByUserId,
  }) async {
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
        @uploadedBy AS uploaded_by,
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
      WHERE tr.result_id = @resultId
        AND COALESCE(tr.is_uploaded, FALSE) = TRUE
        AND COALESCE(tr.attachment_path, '') <> ''
        AND NOT EXISTS (
          SELECT 1
          FROM "UploadpatientR" r
          WHERE r.patient_id = patient.user_id
            AND r.prescribed_doctor_id = matched_prescription.doctor_id
            AND COALESCE(r.file_path, '') = COALESCE(tr.attachment_path, '')
        )
      ''',
      parameters: QueryParameters.named({
        'resultId': resultId,
        'uploadedBy': uploadedByUserId,
      }),
    );
  }

  String _normalizeAnalyticsPatientType(String patientType) {
    final t = patientType.trim().toUpperCase();
    switch (t) {
      case 'STUDENT':
      case 'STAFF':
      case 'OUTSIDE':
      case 'URGENT':
      case 'ALL':
        return t;
      default:
        return 'ALL';
    }
  }

  Future<LabAnalyticsSnapshot> getAnalyticsSnapshot(
    Session session, {
    DateTime? fromDate,
    DateTime? toDateExclusive,
    String patientType = 'ALL',
  }) async {
    try {
      final normalizedType = _normalizeAnalyticsPatientType(patientType);

      final whereConditions = <String>[
        '''
        (
          @ptype::text = 'ALL'
          OR CASE
              WHEN UPPER(COALESCE(tr.patient_type, '')) LIKE '%URGENT%' THEN 'URGENT'
              WHEN UPPER(COALESCE(tr.patient_type, '')) LIKE '%OUTSIDE%'
                OR UPPER(COALESCE(tr.patient_type, '')) LIKE '%PUBLIC%' THEN 'OUTSIDE'
              WHEN UPPER(COALESCE(tr.patient_type, '')) LIKE '%TEACHER%'
                OR UPPER(COALESCE(tr.patient_type, '')) LIKE '%STAFF%' THEN 'STAFF'
              ELSE 'STUDENT'
            END = @ptype::text
        )
        ''',
      ];

      final paramMap = <String, dynamic>{
        'ptype': normalizedType,
      };

      if (fromDate != null) {
        whereConditions.add('COALESCE(tr.created_at, NOW()) >= @fromDate');
        paramMap['fromDate'] = fromDate;
      }
      if (toDateExclusive != null) {
        whereConditions
            .add('COALESCE(tr.created_at, NOW()) < @toDateExclusive');
        paramMap['toDateExclusive'] = toDateExclusive;
      }

      final filterSql = '''
        FROM test_results tr
        LEFT JOIN lab_tests lt ON lt.test_id = tr.test_id
        WHERE ${whereConditions.join(' AND ')}
      ''';

      final parameters = QueryParameters.named(paramMap);

      final summaryRows = await session.db.unsafeQuery(
        '''
        SELECT
          COUNT(*)::int AS total_results,
          SUM(CASE WHEN tr.submitted_at IS NOT NULL THEN 1 ELSE 0 END)::int AS submitted_results,
          SUM(CASE WHEN tr.submitted_at IS NULL THEN 1 ELSE 0 END)::int AS pending_results,
          SUM(CASE
                WHEN UPPER(COALESCE(tr.patient_type, '')) LIKE '%URGENT%' THEN 1
                ELSE 0
              END)::int AS urgent_results,
          COALESCE(AVG(CASE
            WHEN tr.submitted_at IS NOT NULL
              AND COALESCE(tr.created_at, tr.submitted_at) <= tr.submitted_at
            THEN EXTRACT(EPOCH FROM (tr.submitted_at - COALESCE(tr.created_at, tr.submitted_at))) / 3600.0
            ELSE NULL
          END), 0)::double precision AS avg_tat_hours,
          COALESCE(SUM(CASE
            WHEN UPPER(COALESCE(tr.patient_type, '')) LIKE '%OUTSIDE%'
              OR UPPER(COALESCE(tr.patient_type, '')) LIKE '%PUBLIC%' THEN COALESCE(lt.outside_fee, 0)
            WHEN UPPER(COALESCE(tr.patient_type, '')) LIKE '%TEACHER%'
              OR UPPER(COALESCE(tr.patient_type, '')) LIKE '%STAFF%' THEN COALESCE(lt.teacher_fee, 0)
            ELSE COALESCE(lt.student_fee, 0)
          END), 0)::double precision AS estimated_revenue,
          COALESCE(SUM(CASE
            WHEN tr.submitted_at IS NOT NULL THEN
              CASE
                WHEN UPPER(COALESCE(tr.patient_type, '')) LIKE '%OUTSIDE%'
                  OR UPPER(COALESCE(tr.patient_type, '')) LIKE '%PUBLIC%' THEN COALESCE(lt.outside_fee, 0)
                WHEN UPPER(COALESCE(tr.patient_type, '')) LIKE '%TEACHER%'
                  OR UPPER(COALESCE(tr.patient_type, '')) LIKE '%STAFF%' THEN COALESCE(lt.teacher_fee, 0)
                ELSE COALESCE(lt.student_fee, 0)
              END
            ELSE 0
          END), 0)::double precision AS submitted_revenue
        $filterSql
        ''',
        parameters: parameters,
      );

      final summary = summaryRows.isEmpty
          ? <String, dynamic>{}
          : summaryRows.first.toColumnMap();

      final trendRows = await session.db.unsafeQuery(
        '''
        SELECT
          DATE(COALESCE(tr.created_at, NOW()))::timestamp AS day,
          COUNT(*)::int AS total,
          SUM(CASE WHEN tr.submitted_at IS NOT NULL THEN 1 ELSE 0 END)::int AS submitted
        $filterSql
        GROUP BY DATE(COALESCE(tr.created_at, NOW()))
        ORDER BY day ASC
        ''',
        parameters: parameters,
      );

      final topRows = await session.db.unsafeQuery(
        '''
        SELECT
          COALESCE(lt.test_name, 'Test #' || tr.test_id::text) AS test_name,
          COUNT(*)::int AS count
        $filterSql
        GROUP BY COALESCE(lt.test_name, 'Test #' || tr.test_id::text)
        ORDER BY count DESC, test_name ASC
        LIMIT 5
        ''',
        parameters: parameters,
      );

      final categoryRows = await session.db.unsafeQuery(
        '''
        SELECT
          CASE
            WHEN UPPER(COALESCE(tr.patient_type, '')) LIKE '%URGENT%' THEN 'URGENT'
            WHEN UPPER(COALESCE(tr.patient_type, '')) LIKE '%OUTSIDE%'
              OR UPPER(COALESCE(tr.patient_type, '')) LIKE '%PUBLIC%' THEN 'OUTSIDE'
            WHEN UPPER(COALESCE(tr.patient_type, '')) LIKE '%TEACHER%'
              OR UPPER(COALESCE(tr.patient_type, '')) LIKE '%STAFF%' THEN 'STAFF'
            ELSE 'STUDENT'
          END AS category,
          COUNT(*)::int AS count
        $filterSql
        GROUP BY category
        ORDER BY count DESC, category ASC
        ''',
        parameters: parameters,
      );

      final shiftRows = await session.db.unsafeQuery(
        '''
        WITH shift_agg AS (
          SELECT
            CASE
              WHEN EXTRACT(HOUR FROM COALESCE(tr.created_at, NOW())) >= 6
                AND EXTRACT(HOUR FROM COALESCE(tr.created_at, NOW())) < 14 THEN 'Morning'
              WHEN EXTRACT(HOUR FROM COALESCE(tr.created_at, NOW())) >= 14
                AND EXTRACT(HOUR FROM COALESCE(tr.created_at, NOW())) < 22 THEN 'Afternoon'
              ELSE 'Night'
            END AS shift,
            COUNT(*)::int AS total,
            SUM(CASE WHEN tr.submitted_at IS NOT NULL THEN 1 ELSE 0 END)::int AS submitted
          $filterSql
          GROUP BY 1
        )
        SELECT shift, total, submitted
        FROM shift_agg
        ORDER BY CASE shift
          WHEN 'Morning' THEN 1
          WHEN 'Afternoon' THEN 2
          ELSE 3
        END
        ''',
        parameters: parameters,
      );

      return LabAnalyticsSnapshot(
        totalResults: (summary['total_results'] as int?) ?? 0,
        submittedResults: (summary['submitted_results'] as int?) ?? 0,
        pendingResults: (summary['pending_results'] as int?) ?? 0,
        urgentResults: (summary['urgent_results'] as int?) ?? 0,
        avgTatHours: _toDouble(summary['avg_tat_hours']),
        estimatedRevenue: _toDouble(summary['estimated_revenue']),
        submittedRevenue: _toDouble(summary['submitted_revenue']),
        fromDate: fromDate,
        toDateExclusive: toDateExclusive,
        patientType: normalizedType,
        dailyTrend: trendRows.map((r) {
          final m = r.toColumnMap();
          return LabAnalyticsDailyPoint(
            day: (m['day'] as DateTime?) ?? DateTime.now(),
            total: (m['total'] as int?) ?? 0,
            submitted: (m['submitted'] as int?) ?? 0,
          );
        }).toList(),
        topTests: topRows.map((r) {
          final m = r.toColumnMap();
          return LabAnalyticsTestCount(
            testName: _safeString(m['test_name']),
            count: (m['count'] as int?) ?? 0,
          );
        }).toList(),
        categoryDistribution: categoryRows.map((r) {
          final m = r.toColumnMap();
          return LabAnalyticsCategoryCount(
            category: _safeString(m['category']),
            count: (m['count'] as int?) ?? 0,
          );
        }).toList(),
        shiftProductivity: shiftRows.map((r) {
          final m = r.toColumnMap();
          final total = (m['total'] as int?) ?? 0;
          final submitted = (m['submitted'] as int?) ?? 0;
          final productivityPercent =
              total == 0 ? 0.0 : (submitted * 100.0) / total;

          return LabAnalyticsShiftStat(
            shift: _safeString(m['shift']),
            total: total,
            submitted: submitted,
            productivityPercent: productivityPercent,
          );
        }).toList(),
      );
    } catch (e, st) {
      session.log('Failed to build lab analytics snapshot: $e',
          level: LogLevel.error, stackTrace: st);
      rethrow;
    }
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
        return 'CS';
    }
  }

  Future<void> _notifyUserByMobile(
    Session session, {
    required String mobileNumber,
    required String title,
    required String message,
  }) async {
    final normalizedMobile = mobileNumber.trim();
    if (normalizedMobile.isEmpty) return;

    final userRows = await session.db.unsafeQuery(
      '''
      SELECT user_id
      FROM users
      WHERE phone = @mobile
      LIMIT 1
      ''',
      parameters: QueryParameters.named({'mobile': normalizedMobile}),
    );

    if (userRows.isEmpty) return;

    final userId = userRows.first.toColumnMap()['user_id'] as int?;
    if (userId == null) return;

    await session.db.unsafeExecute(
      '''
      INSERT INTO notifications (user_id, title, message, is_read, created_at)
      VALUES (@uid, @title, @message, FALSE, NOW())
      ''',
      parameters: QueryParameters.named({
        'uid': userId,
        'title': title,
        'message': message,
      }),
    );
  }

  Future<LabPaymentItem?> _getPaymentItemById(
      Session session, int resultId) async {
    await _ensurePaymentColumns(session);
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
      isUploaded: (m['is_uploaded'] as bool?) ?? false,
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

  /// Fetch all lab tests using your raw SQL schema
  Future<List<LabTests>> getAllLabTests(Session session) async {
    try {
      final result = await session.db.unsafeQuery(
        '''SELECT test_id, test_name, description, student_fee, teacher_fee, outside_fee, available 
           FROM lab_tests 
           ORDER BY test_name ASC''',
      );

      return result.map((r) {
        final row = r.toColumnMap();

        return LabTests(
          id: row['test_id'] as int?, // Ekhon eti constructor-e kaj korbe
          testName: _safeString(row['test_name']),
          description: _safeString(row['description']),
          studentFee: _toDouble(row['student_fee']),
          teacherFee: _toDouble(row['teacher_fee']),
          outsideFee: _toDouble(row['outside_fee']),
          available: row['available'] as bool? ?? true,
        );
      }).toList();
    } catch (e, stackTrace) {
      session.log('Error fetching lab tests: $e',
          level: LogLevel.error, stackTrace: stackTrace);
      return [];
    }
  }

  //result upload er jonnne user er test create
  Future<bool> createTestResult(
    Session session, {
    required int testId,
    required String patientName,
    required String mobileNumber,
    String patientType = 'STUDENT',
  }) async {
    try {
      final normalizedName =
          patientName.trim().isEmpty ? 'Unknown Patient' : patientName.trim();
      final normalizedMobile = mobileNumber.trim();
      final requestedType = patientType.trim().toUpperCase();
      final normalizedType = switch (requestedType) {
        'STUDENT' => 'STUDENT',
        'STAFF' => 'STAFF',
        'OUTSIDE' => 'OUTSIDE',
        // Backward compatibility if any old client still sends TEACHER
        'TEACHER' => 'STAFF',
        _ => 'STUDENT',
      };

      // Some deployed DBs may not yet have all expected columns.
      // Detect schema and insert accordingly to avoid runtime failure.
      final nameColumn = await session.db.unsafeQuery(
        '''
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'test_results'
          AND column_name = 'patient_name'
        LIMIT 1
        ''',
      );

      final createdAtColumn = await session.db.unsafeQuery(
        '''
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'test_results'
          AND column_name = 'created_at'
        LIMIT 1
        ''',
      );

      final hasPatientNameColumn = nameColumn.isNotEmpty;
      final hasCreatedAtColumn = createdAtColumn.isNotEmpty;

      if (hasPatientNameColumn && hasCreatedAtColumn) {
        await session.db.unsafeExecute(
          '''
          INSERT INTO test_results
          (test_id, patient_name, mobile_number, patient_type, created_at)
          VALUES (@testId, @patientName, @mobile, @patientType, NOW())
          ''',
          parameters: QueryParameters.named({
            'testId': testId,
            'patientName': normalizedName,
            'mobile': normalizedMobile,
            'patientType': normalizedType,
          }),
        );
      } else if (hasPatientNameColumn && !hasCreatedAtColumn) {
        await session.db.unsafeExecute(
          '''
          INSERT INTO test_results
          (test_id, patient_name, mobile_number, patient_type)
          VALUES (@testId, @patientName, @mobile, @patientType)
          ''',
          parameters: QueryParameters.named({
            'testId': testId,
            'patientName': normalizedName,
            'mobile': normalizedMobile,
            'patientType': normalizedType,
          }),
        );
      } else if (!hasPatientNameColumn && hasCreatedAtColumn) {
        await session.db.unsafeExecute(
          '''
          INSERT INTO test_results
          (test_id, mobile_number, patient_type, created_at)
          VALUES (@testId, @mobile, @patientType, NOW())
          ''',
          parameters: QueryParameters.named({
            'testId': testId,
            'mobile': normalizedMobile,
            'patientType': normalizedType,
          }),
        );
      } else {
        await session.db.unsafeExecute(
          '''
          INSERT INTO test_results
          (test_id, mobile_number, patient_type)
          VALUES (@testId, @mobile, @patientType)
          ''',
          parameters: QueryParameters.named({
            'testId': testId,
            'mobile': normalizedMobile,
            'patientType': normalizedType,
          }),
        );
      }
      return true;
    } catch (e, st) {
      session.log('Create test result failed: $e',
          level: LogLevel.error, stackTrace: st);
      return false;
    }
  }

  /// Create a new lab test record
  Future<bool> createLabTest(Session session, LabTests test) async {
    try {
      await session.db.unsafeExecute(
        '''INSERT INTO lab_tests (test_name, description, student_fee, teacher_fee, outside_fee, available)
           VALUES (@testName, @description, @studentFee, @teacherFee, @outsideFee, @available)''',
        parameters: QueryParameters.named({
          'testName': test.testName,
          'description': test.description,
          'studentFee': test.studentFee,
          'teacherFee': test.teacherFee,
          'outsideFee': test.outsideFee,
          'available': test.available,
        }),
      );
      return true;
    } catch (e, stackTrace) {
      session.log('Error creating lab test: $e',
          level: LogLevel.error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Update an existing lab test (Admin style using QueryParameters)
  Future<bool> updateLabTest(Session session, LabTests test) async {
    if (test.id == null) return false;
    try {
      // AdminEndpoints-er moto unsafeExecute ebong QueryParameters use kora hoyeche
      await session.db.unsafeExecute(
        '''UPDATE lab_tests 
           SET test_name = @testName, 
               description = @description, 
               student_fee = @studentFee, 
               teacher_fee = @teacherFee, 
               outside_fee = @outsideFee, 
               available = @available
           WHERE test_id = @id''',
        parameters: QueryParameters.named({
          'id': test.id,
          'testName': test.testName,
          'description': test.description,
          'studentFee': test.studentFee,
          'teacherFee': test.teacherFee,
          'outsideFee': test.outsideFee,
          'available': test.available,
        }),
      );
      return true;
    } catch (e, stackTrace) {
      session.log('Error updating lab test: $e',
          level: LogLevel.error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Dummy SMS sender: logs message to server logs (no real SMS)
  Future<bool> sendDummySms(Session session,
      {required String mobileNumber, required String message}) async {
    // simulate sending delay
    await Future.delayed(const Duration(milliseconds: 500));

    session.log('We sent a SMS TO: $mobileNumber');
    session.log('Message: $message');
    return true;
  }
//submit result

  Future<bool> submitResult(
    Session session, {
    required int resultId,
  }) async {
    try {
      await session.db.unsafeExecute(
        '''
      UPDATE test_results
      SET submitted_at = NOW()
      WHERE result_id = @id
      ''',
        parameters: QueryParameters.named({
          'id': resultId,
        }),
      );
      return true;
    } catch (e, st) {
      session.log('Submit result failed: $e',
          level: LogLevel.error, stackTrace: st);
      return false;
    }
  }

  Future<List<LabPaymentItem>> getLabPaymentItems(Session session) async {
    try {
      await _ensurePaymentColumns(session);
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
        ORDER BY COALESCE(tr.created_at, NOW()) DESC, tr.result_id DESC
        ''',
      );

      return rows.map((r) => _mapLabPaymentItem(r.toColumnMap())).toList();
    } catch (e, st) {
      session.log('Fetch lab payment items failed: $e',
          level: LogLevel.error, stackTrace: st);
      return [];
    }
  }

  Future<LabPaymentItem?> collectCashPayment(
    Session session, {
    required int resultId,
  }) async {
    try {
      await _ensurePaymentColumns(session);
      final now = DateTime.now();
      final txn =
          '${_paymentTxnPrefix('CASH')}-$resultId-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
      await session.db.unsafeExecute(
        '''
        UPDATE test_results
        SET payment_status = 'PAID',
            payment_method = 'CASH',
            transaction_id = COALESCE(transaction_id, @txn),
            paid_at = COALESCE(paid_at, NOW())
        WHERE result_id = @id
        ''',
        parameters: QueryParameters.named({'id': resultId, 'txn': txn}),
      );
      final item = await _getPaymentItemById(session, resultId);
      if (item != null) {
        await _notifyUserByMobile(
          session,
          mobileNumber: item.mobileNumber,
          title: 'Payment Updated',
          message:
              'Your lab payment is marked as PAID for ${item.testName}. Transaction: ${item.transactionId ?? 'N/A'}',
        );
      }
      return item;
    } catch (e, st) {
      session.log('Collect cash payment failed: $e',
          level: LogLevel.error, stackTrace: st);
      return null;
    }
  }

  Future<LabPaymentItem?> markPatientNotified(
    Session session, {
    required int resultId,
  }) async {
    try {
      await _ensurePaymentColumns(session);
      await session.db.unsafeExecute(
        '''
        UPDATE test_results
        SET patient_notified_at = NOW()
        WHERE result_id = @id
        ''',
        parameters: QueryParameters.named({'id': resultId}),
      );

      final item = await _getPaymentItemById(session, resultId);
      if (item != null) {
        await sendDummySms(
          session,
          mobileNumber: item.mobileNumber,
          message:
              'প্রিয় ${item.patientName}, আপনার payment received হয়েছে। ট্রানজ্যাকশন: ${item.transactionId ?? 'N/A'}',
        );
      }

      return item;
    } catch (e, st) {
      session.log('Mark patient notified failed: $e',
          level: LogLevel.error, stackTrace: st);
      return null;
    }
  }

  /// Submit or resubmit result + dummy SMS notification.
  /// Upload happens on frontend; backend only stores the URL.
  Future<bool> submitResultWithUrl(
    Session session, {
    required int resultId,
    required String attachmentUrl,
  }) async {
    try {
      final resolvedUserId = requireAuthenticatedUserId(session);
      final url = attachmentUrl.trim();
      if (!(url.startsWith('http://') || url.startsWith('https://'))) {
        return false;
      }

      // Enforce replacement window: allow replace only within 24h of first upload.
      // - If never uploaded (is_uploaded=false OR submitted_at is null): allow.
      // - If already uploaded and submitted_at older than 24h: reject.
      final stateRows = await session.db.unsafeQuery(
        r'''
        SELECT
          is_uploaded,
          submitted_at,
          (submitted_at IS NOT NULL AND submitted_at < (NOW() - INTERVAL '24 hours')) AS expired
        FROM test_results
        WHERE result_id = @id
        LIMIT 1
        ''',
        parameters: QueryParameters.named({'id': resultId}),
      );

      if (stateRows.isEmpty) return false;
      final state = stateRows.first.toColumnMap();
      final isUploaded = (state['is_uploaded'] as bool?) ?? false;
      final expired = (state['expired'] as bool?) ?? false;
      if (isUploaded && expired) {
        return false;
      }

      // Save URL and timestamp in DB
      await session.db.unsafeExecute(
        '''
      UPDATE test_results
      SET attachment_path = @url,
          is_uploaded = TRUE,
          submitted_at = COALESCE(submitted_at, NOW())
      WHERE result_id = @id
      ''',
        parameters: QueryParameters.named({
          'id': resultId,
          'url': url,
        }),
      );

      await _mirrorUploadedResultToDoctorReports(
        session,
        resultId: resultId,
        uploadedByUserId: resolvedUserId,
      );

      // Notify assigned doctor about newly submitted lab report.
      try {
        final metaRows = await session.db.unsafeQuery(
          '''
          SELECT
            COALESCE(NULLIF(lt.test_name, ''), 'Lab Report') AS report_type,
            COALESCE(NULLIF(tr.patient_name, ''), 'Patient') AS patient_name,
            tr.mobile_number
          FROM test_results tr
          LEFT JOIN lab_tests lt ON lt.test_id = tr.test_id
          WHERE tr.result_id = @resultId
          LIMIT 1
          ''',
          parameters: QueryParameters.named({'resultId': resultId}),
        );

        if (metaRows.isEmpty) {
          session.log(
            'Doctor notification skipped: missing test_results row for resultId=$resultId',
            level: LogLevel.warning,
          );
        }

        final meta = metaRows.isEmpty
            ? <String, dynamic>{}
            : metaRows.first.toColumnMap();
        final reportType = meta['report_type']?.toString() ?? 'Lab Report';
        final patientName = meta['patient_name']?.toString() ?? 'Patient';
        final mobileNumber = meta['mobile_number']?.toString() ?? '';

        final doctorRows = await session.db.unsafeQuery(
          '''
          WITH matched_patient AS (
            SELECT u.user_id
            FROM users u
            WHERE RIGHT(REGEXP_REPLACE(COALESCE(u.phone, ''), '[^0-9]', '', 'g'), 11)
                = RIGHT(REGEXP_REPLACE(@mobile, '[^0-9]', '', 'g'), 11)
            LIMIT 1
          )
          SELECT DISTINCT doctor_id
          FROM (
            SELECT r.prescribed_doctor_id AS doctor_id
            FROM "UploadpatientR" r
            WHERE COALESCE(r.file_path, '') = @url
              AND r.prescribed_doctor_id IS NOT NULL

            UNION

            SELECT p.doctor_id AS doctor_id
            FROM prescriptions p
            JOIN matched_patient mp ON mp.user_id = p.patient_id
          ) doctors
          WHERE doctor_id IS NOT NULL
          ''',
          parameters:
              QueryParameters.named({'url': url, 'mobile': mobileNumber}),
        );

        final fallbackDoctorRows = await session.db.unsafeQuery(
          '''
          SELECT DISTINCT p.doctor_id
          FROM test_results tr
          JOIN users u
            ON RIGHT(REGEXP_REPLACE(COALESCE(u.phone, ''), '[^0-9]', '', 'g'), 11)
             = RIGHT(REGEXP_REPLACE(COALESCE(tr.mobile_number, ''), '[^0-9]', '', 'g'), 11)
          JOIN prescriptions p ON p.patient_id = u.user_id
          WHERE tr.result_id = @resultId
          ''',
          parameters: QueryParameters.named({'resultId': resultId}),
        );

        final doctorIds = <int>{
          ...doctorRows
              .map((r) => r.toColumnMap()['doctor_id'] as int?)
              .whereType<int>(),
          ...fallbackDoctorRows
              .map((r) => r.toColumnMap()['doctor_id'] as int?)
              .whereType<int>(),
        };

        if (doctorIds.isEmpty) {
          session.log(
            'No doctor recipients resolved for lab submit notification. resultId=$resultId, mobile=$mobileNumber, url=$url',
            level: LogLevel.warning,
          );
        } else {
          session.log(
            'Resolved doctor recipients for lab submit notification. resultId=$resultId, doctors=${doctorIds.join(',')}',
            level: LogLevel.info,
          );
        }

        for (final doctorId in doctorIds) {
          await session.db.unsafeExecute(
            '''
            INSERT INTO notifications (user_id, title, message, is_read, created_at)
            VALUES (@uid, @title, @message, FALSE, NOW())
            ''',
            parameters: QueryParameters.named({
              'uid': doctorId,
              'title': 'New Lab Report Submitted',
              'message':
                  '$patientName submitted $reportType. Please review it from your reports page. [route:/doctor/reports]',
            }),
          );
        }
      } catch (notifyError, notifyStack) {
        session.log(
          'Doctor notification for lab submit failed: $notifyError',
          level: LogLevel.warning,
          stackTrace: notifyStack,
        );
      }

      // Optionally, send SMS
      final rows = await session.db.unsafeQuery(
        'SELECT patient_name, mobile_number FROM test_results WHERE result_id = @id',
        parameters: QueryParameters.named({'id': resultId}),
      );

      if (rows.isNotEmpty) {
        final m = rows.first.toColumnMap();
        final name = m['patient_name']?.toString() ?? 'Patient';
        final mobile = m['mobile_number']?.toString() ?? '';
        final message =
            'প্রিয় $name, আপনার lab result submit হয়েছে।\nডাউনলোড লিংক: $url';
        await sendDummySms(session, mobileNumber: mobile, message: message);

        await _notifyUserByMobile(
          session,
          mobileNumber: mobile,
          title: 'Test Report Updated',
          message:
              'Your test report is now available. You can view/download it from your reports section.',
        );
      }

      return true;
    } catch (e, st) {
      session.log('Submit with file failed: $e',
          level: LogLevel.error, stackTrace: st);
      return false;
    }
  }

//Fetch all results (list screen)
  Future<List<TestResult>> getAllTestResults(Session session) async {
    try {
      final columns = await session.db.unsafeQuery(
        '''
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'test_results'
        ''',
      );

      final availableColumns = columns
          .map((r) => r.toColumnMap()['column_name']?.toString() ?? '')
          .toSet();

      final hasPatientName = availableColumns.contains('patient_name');
      final hasPatientType = availableColumns.contains('patient_type');
      final hasIsUploaded = availableColumns.contains('is_uploaded');
      final hasAttachmentPath = availableColumns.contains('attachment_path');
      final hasSubmittedAt = availableColumns.contains('submitted_at');
      final hasCreatedAt = availableColumns.contains('created_at');

      final sql = '''
      SELECT
        result_id,
        test_id,
        ${hasPatientName ? 'patient_name' : "''::text AS patient_name"},
        mobile_number,
        ${hasPatientType ? 'patient_type' : "''::text AS patient_type"},
        ${hasIsUploaded ? 'is_uploaded' : 'FALSE AS is_uploaded'},
        ${hasAttachmentPath ? 'attachment_path' : 'NULL::text AS attachment_path'},
        ${hasSubmittedAt ? 'submitted_at' : 'NULL::timestamp AS submitted_at'},
        ${hasCreatedAt ? 'created_at' : 'NULL::timestamp AS created_at'}
      FROM test_results
      ORDER BY ${hasCreatedAt ? 'created_at DESC NULLS LAST, result_id DESC' : 'result_id DESC'}
      ''';

      final rows = await session.db.unsafeQuery(
        sql,
      );

      return rows.map((r) {
        final m = r.toColumnMap();
        return TestResult(
          resultId: m['result_id'] as int,
          testId: m['test_id'] as int,
          patientName: _safeString(m['patient_name']),
          mobileNumber: _safeString(m['mobile_number']),
          patientType: _safeString(m['patient_type']),
          isUploaded: (m['is_uploaded'] as bool?) ?? false,
          attachmentPath: m['attachment_path'] as String?,
          submittedAt: m['submitted_at'] as DateTime?,
          createdAt: m['created_at'] as DateTime?,
        );
      }).toList();
    } catch (e, st) {
      session.log('Fetch results failed: $e',
          level: LogLevel.error, stackTrace: st);
      return [];
    }
  }

  /// Fetch Lab Staff profile for the authenticated user
  Future<StaffProfileDto?> getStaffProfile(Session session) async {
    try {
      final resolvedUserId = requireAuthenticatedUserId(session);
      final result = await session.db.unsafeQuery(
        '''
        SELECT 
          u.name, 
          u.email, 
          u.phone, 
          u.profile_picture_url,
          s.designation, 
          s.qualification
        FROM users u
        LEFT JOIN staff_profiles s ON s.user_id = u.user_id
        WHERE u.user_id = @userId LIMIT 1
        ''',
        parameters: QueryParameters.named({'userId': resolvedUserId}),
      );

      if (result.isEmpty) return null;

      final row = result.first.toColumnMap();

      return StaffProfileDto(
        name: _safeString(row['name']),
        email: _safeString(row['email']),
        phone: _safeString(row['phone']),
        designation: _safeString(row['designation']),
        qualification: _safeString(row['qualification']),
        profilePictureUrl: row['profile_picture_url'] as String?,
      );
    } catch (e, stack) {
      session.log('Error fetching staff profile: $e',
          level: LogLevel.error, stackTrace: stack);
      return null;
    }
  }

  /// Update Staff Profile (Users + Staff_Profiles tables)
  Future<bool> updateStaffProfile(
    Session session, {
    required String name,
    required String phone,
    required String email,
    required String designation,
    required String qualification,
    String? profilePictureUrl,
  }) async {
    try {
      final resolvedUserId = requireAuthenticatedUserId(session);
      final normalizedProfilePictureUrl = (profilePictureUrl != null &&
              profilePictureUrl.trim().isNotEmpty &&
              (profilePictureUrl.trim().startsWith('http://') ||
                  profilePictureUrl.trim().startsWith('https://')))
          ? profilePictureUrl.trim()
          : null;
      return await session.db.transaction((transaction) async {
        // 1. Update Core User Info
        await session.db.unsafeExecute(
          '''
          UPDATE users 
          SET name = @name, 
              phone = @phone,
              email = @email,
              profile_picture_url = COALESCE(@url, profile_picture_url)
          WHERE user_id = @id
          ''',
          parameters: QueryParameters.named({
            'id': resolvedUserId,
            'name': name,
            'phone': phone,
            'email': email,
            'url': normalizedProfilePictureUrl,
          }),
        );

        // 2. Upsert Staff Specific Info
        await session.db.unsafeExecute(
          '''
          INSERT INTO staff_profiles (user_id, designation, qualification)
          VALUES (@id, @des, @qual)
          ON CONFLICT (user_id)
          DO UPDATE SET 
            designation = EXCLUDED.designation,
            qualification = EXCLUDED.qualification
          ''',
          parameters: QueryParameters.named({
            'id': resolvedUserId,
            'des': designation,
            'qual': qualification,
          }),
        );

        return true;
      });
    } catch (e, stack) {
      session.log('Failed to update staff profile: $e',
          level: LogLevel.error, stackTrace: stack);
      return false;
    }
  }

  // --- Type Safety Helpers ---

  String _safeString(dynamic value) {
    if (value == null) return '';

    try {
      // ✅ handles UndecodedBytes WITHOUT referencing the type
      if (value.runtimeType.toString() == 'UndecodedBytes') {
        final bytes = (value as dynamic).bytes as List<int>;
        return utf8.decode(bytes);
      }

      if (value is Uint8List) {
        return utf8.decode(value);
      }

      if (value is Iterable<int>) {
        return utf8.decode(value.toList());
      }
    } catch (_) {
      // ignore decode errors
    }
    return value.toString();
  }

  Future<LabToday> getLabHomeTwoDaySummary(Session session) async {
    final todayRows = await session.db.unsafeQuery(r'''
    SELECT
      COUNT(*)::int AS total,
      SUM(CASE WHEN is_uploaded = FALSE THEN 1 ELSE 0 END)::int AS pending_uploads,
      SUM(CASE WHEN submitted_at IS NOT NULL THEN 1 ELSE 0 END)::int AS submitted
    FROM test_results
    WHERE created_at::date = CURRENT_DATE
  ''');

    final yesterdayRows = await session.db.unsafeQuery(r'''
    SELECT
      COUNT(*)::int AS total,
      SUM(CASE WHEN is_uploaded = FALSE THEN 1 ELSE 0 END)::int AS pending_uploads,
      SUM(CASE WHEN submitted_at IS NOT NULL THEN 1 ELSE 0 END)::int AS submitted
    FROM test_results
    WHERE created_at::date = (CURRENT_DATE - INTERVAL '1 day')::date
  ''');

    final t = todayRows.isNotEmpty
        ? todayRows.first.toColumnMap()
        : <String, dynamic>{};
    final y = yesterdayRows.isNotEmpty
        ? yesterdayRows.first.toColumnMap()
        : <String, dynamic>{};

    return LabToday(
      todayTotal: (t['total'] as int?) ?? 0,
      todayPendingUploads: (t['pending_uploads'] as int?) ?? 0,
      todaySubmitted: (t['submitted'] as int?) ?? 0,
      yesterdayTotal: (y['total'] as int?) ?? 0,
      yesterdayPendingUploads: (y['pending_uploads'] as int?) ?? 0,
      yesterdaySubmitted: (y['submitted'] as int?) ?? 0,
    );
  }

  Future<List<LabTenHistory>> getLast10TestHistory(Session session) async {
    final rows = await session.db.unsafeQuery(r'''
    SELECT
      tr.result_id,
      tr.test_id,
      lt.test_name,
      tr.patient_name,
      tr.mobile_number,
      tr.is_uploaded,
      tr.submitted_at,
      tr.created_at
    FROM test_results tr
    LEFT JOIN lab_tests lt ON lt.test_id = tr.test_id
    ORDER BY tr.created_at DESC
    LIMIT 10
  ''');

    return rows.map((r) {
      final m = r.toColumnMap();
      return LabTenHistory(
        resultId: m['result_id'] as int,
        testId: m['test_id'] as int,
        testName: m['test_name']?.toString(),
        patientName: (m['patient_name']?.toString() ?? ''),
        mobileNumber: (m['mobile_number']?.toString() ?? ''),
        isUploaded: (m['is_uploaded'] as bool?) ?? false,
        submittedAt: m['submitted_at'] as DateTime?,
        createdAt: m['created_at'] as DateTime?,
      );
    }).toList();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    // PostgreSQL NUMERIC often comes back as a String or double via the driver
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

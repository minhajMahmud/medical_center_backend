/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'package:serverpod/protocol.dart' as _i2;
import 'InventoryCategory.dart' as _i3;
import 'InventoryItemInfo.dart' as _i4;
import 'PrescribedItem.dart' as _i5;
import 'StaffInfo.dart' as _i6;
import 'admin_dashboard_overview.dart' as _i7;
import 'admin_profile.dart' as _i8;
import 'ambulance_contact.dart' as _i9;
import 'appointment_request_item.dart' as _i10;
import 'audit_entry.dart' as _i11;
import 'dashboard_analytics.dart' as _i12;
import 'dispense_history_entry.dart' as _i13;
import 'dispense_item_detail.dart' as _i14;
import 'dispense_request.dart' as _i15;
import 'dispensed_item_input.dart' as _i16;
import 'dispensed_item_summary.dart' as _i17;
import 'dispenser_profile_r.dart' as _i18;
import 'doctor_home_data.dart' as _i19;
import 'doctor_home_recent_item.dart' as _i20;
import 'doctor_home_reviewed_report.dart' as _i21;
import 'doctor_profile.dart' as _i22;
import 'external_report_file.dart' as _i23;
import 'greeting.dart' as _i24;
import 'inventory_audit_log.dart' as _i25;
import 'inventory_transaction.dart' as _i26;
import 'lab_analytics_category_count.dart' as _i27;
import 'lab_analytics_daily_point.dart' as _i28;
import 'lab_analytics_shift_stat.dart' as _i29;
import 'lab_analytics_snapshot.dart' as _i30;
import 'lab_analytics_test_count.dart' as _i31;
import 'lab_payment_item.dart' as _i32;
import 'lab_ten_history.dart' as _i33;
import 'lab_today.dart' as _i34;
import 'login_response.dart' as _i35;
import 'medicine_alternative.dart' as _i36;
import 'medicine_details.dart' as _i37;
import 'notification.dart' as _i38;
import 'onduty_staff.dart' as _i39;
import 'otp_challenge_response.dart' as _i40;
import 'patient_external_report.dart' as _i41;
import 'patient_record_list.dart' as _i42;
import 'patient_record_prescribed_item.dart' as _i43;
import 'patient_record_prescription_details.dart' as _i44;
import 'patient_reponse.dart' as _i45;
import 'patient_report.dart' as _i46;
import 'patient_return_tests.dart' as _i47;
import 'prescription.dart' as _i48;
import 'prescription_detail.dart' as _i49;
import 'prescription_list.dart' as _i50;
import 'report_lab_test_range.dart' as _i51;
import 'report_medicine_stock_range.dart' as _i52;
import 'report_monthly.dart' as _i53;
import 'report_prescription.dart' as _i54;
import 'report_stock.dart' as _i55;
import 'report_top_medicine.dart' as _i56;
import 'roster_data.dart' as _i57;
import 'roster_lists.dart' as _i58;
import 'roster_user_role.dart' as _i59;
import 'shift_type.dart' as _i60;
import 'staff_profile.dart' as _i61;
import 'test_result_create_upload.dart' as _i62;
import 'user_list_item.dart' as _i63;
import 'package:backend_server/src/generated/user_list_item.dart' as _i64;
import 'package:backend_server/src/generated/roster_data.dart' as _i65;
import 'package:backend_server/src/generated/roster_lists.dart' as _i66;
import 'package:backend_server/src/generated/audit_entry.dart' as _i67;
import 'package:backend_server/src/generated/InventoryCategory.dart' as _i68;
import 'package:backend_server/src/generated/InventoryItemInfo.dart' as _i69;
import 'package:backend_server/src/generated/inventory_transaction.dart'
    as _i70;
import 'package:backend_server/src/generated/inventory_audit_log.dart' as _i71;
import 'package:backend_server/src/generated/report_top_medicine.dart' as _i72;
import 'package:backend_server/src/generated/report_medicine_stock_range.dart'
    as _i73;
import 'package:backend_server/src/generated/report_lab_test_range.dart'
    as _i74;
import 'package:backend_server/src/generated/prescription.dart' as _i75;
import 'package:backend_server/src/generated/dispense_request.dart' as _i76;
import 'package:backend_server/src/generated/dispense_history_entry.dart'
    as _i77;
import 'package:backend_server/src/generated/PrescribedItem.dart' as _i78;
import 'package:backend_server/src/generated/patient_external_report.dart'
    as _i79;
import 'package:backend_server/src/generated/patient_record_list.dart' as _i80;
import 'package:backend_server/src/generated/appointment_request_item.dart'
    as _i81;
import 'package:backend_server/src/generated/patient_return_tests.dart' as _i82;
import 'package:backend_server/src/generated/lab_payment_item.dart' as _i83;
import 'package:backend_server/src/generated/test_result_create_upload.dart'
    as _i84;
import 'package:backend_server/src/generated/lab_ten_history.dart' as _i85;
import 'package:backend_server/src/generated/notification.dart' as _i86;
import 'package:backend_server/src/generated/patient_report.dart' as _i87;
import 'package:backend_server/src/generated/prescription_list.dart' as _i88;
import 'package:backend_server/src/generated/StaffInfo.dart' as _i89;
import 'package:backend_server/src/generated/ambulance_contact.dart' as _i90;
import 'package:backend_server/src/generated/onduty_staff.dart' as _i91;
export 'InventoryCategory.dart';
export 'InventoryItemInfo.dart';
export 'PrescribedItem.dart';
export 'StaffInfo.dart';
export 'admin_dashboard_overview.dart';
export 'admin_profile.dart';
export 'ambulance_contact.dart';
export 'appointment_request_item.dart';
export 'audit_entry.dart';
export 'dashboard_analytics.dart';
export 'dispense_history_entry.dart';
export 'dispense_item_detail.dart';
export 'dispense_request.dart';
export 'dispensed_item_input.dart';
export 'dispensed_item_summary.dart';
export 'dispenser_profile_r.dart';
export 'doctor_home_data.dart';
export 'doctor_home_recent_item.dart';
export 'doctor_home_reviewed_report.dart';
export 'doctor_profile.dart';
export 'external_report_file.dart';
export 'greeting.dart';
export 'inventory_audit_log.dart';
export 'inventory_transaction.dart';
export 'lab_analytics_category_count.dart';
export 'lab_analytics_daily_point.dart';
export 'lab_analytics_shift_stat.dart';
export 'lab_analytics_snapshot.dart';
export 'lab_analytics_test_count.dart';
export 'lab_payment_item.dart';
export 'lab_ten_history.dart';
export 'lab_today.dart';
export 'login_response.dart';
export 'medicine_alternative.dart';
export 'medicine_details.dart';
export 'notification.dart';
export 'onduty_staff.dart';
export 'otp_challenge_response.dart';
export 'patient_external_report.dart';
export 'patient_record_list.dart';
export 'patient_record_prescribed_item.dart';
export 'patient_record_prescription_details.dart';
export 'patient_reponse.dart';
export 'patient_report.dart';
export 'patient_return_tests.dart';
export 'prescription.dart';
export 'prescription_detail.dart';
export 'prescription_list.dart';
export 'report_lab_test_range.dart';
export 'report_medicine_stock_range.dart';
export 'report_monthly.dart';
export 'report_prescription.dart';
export 'report_stock.dart';
export 'report_top_medicine.dart';
export 'roster_data.dart';
export 'roster_lists.dart';
export 'roster_user_role.dart';
export 'shift_type.dart';
export 'staff_profile.dart';
export 'test_result_create_upload.dart';
export 'user_list_item.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    ..._i2.Protocol.targetTableDefinitions,
  ];

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i3.InventoryCategory) {
      return _i3.InventoryCategory.fromJson(data) as T;
    }
    if (t == _i4.InventoryItemInfo) {
      return _i4.InventoryItemInfo.fromJson(data) as T;
    }
    if (t == _i5.PrescribedItem) {
      return _i5.PrescribedItem.fromJson(data) as T;
    }
    if (t == _i6.StaffInfo) {
      return _i6.StaffInfo.fromJson(data) as T;
    }
    if (t == _i7.AdminDashboardOverview) {
      return _i7.AdminDashboardOverview.fromJson(data) as T;
    }
    if (t == _i8.AdminProfileRespond) {
      return _i8.AdminProfileRespond.fromJson(data) as T;
    }
    if (t == _i9.AmbulanceContact) {
      return _i9.AmbulanceContact.fromJson(data) as T;
    }
    if (t == _i10.AppointmentRequestItem) {
      return _i10.AppointmentRequestItem.fromJson(data) as T;
    }
    if (t == _i11.AuditEntry) {
      return _i11.AuditEntry.fromJson(data) as T;
    }
    if (t == _i12.DashboardAnalytics) {
      return _i12.DashboardAnalytics.fromJson(data) as T;
    }
    if (t == _i13.DispenseHistoryEntry) {
      return _i13.DispenseHistoryEntry.fromJson(data) as T;
    }
    if (t == _i14.DispenseItemDetail) {
      return _i14.DispenseItemDetail.fromJson(data) as T;
    }
    if (t == _i15.DispenseItemRequest) {
      return _i15.DispenseItemRequest.fromJson(data) as T;
    }
    if (t == _i16.DispensedItemInput) {
      return _i16.DispensedItemInput.fromJson(data) as T;
    }
    if (t == _i17.DispensedItemSummary) {
      return _i17.DispensedItemSummary.fromJson(data) as T;
    }
    if (t == _i18.DispenserProfileR) {
      return _i18.DispenserProfileR.fromJson(data) as T;
    }
    if (t == _i19.DoctorHomeData) {
      return _i19.DoctorHomeData.fromJson(data) as T;
    }
    if (t == _i20.DoctorHomeRecentItem) {
      return _i20.DoctorHomeRecentItem.fromJson(data) as T;
    }
    if (t == _i21.DoctorHomeReviewedReport) {
      return _i21.DoctorHomeReviewedReport.fromJson(data) as T;
    }
    if (t == _i22.DoctorProfile) {
      return _i22.DoctorProfile.fromJson(data) as T;
    }
    if (t == _i23.ExternalReportFile) {
      return _i23.ExternalReportFile.fromJson(data) as T;
    }
    if (t == _i24.Greeting) {
      return _i24.Greeting.fromJson(data) as T;
    }
    if (t == _i25.InventoryAuditLog) {
      return _i25.InventoryAuditLog.fromJson(data) as T;
    }
    if (t == _i26.InventoryTransactionInfo) {
      return _i26.InventoryTransactionInfo.fromJson(data) as T;
    }
    if (t == _i27.LabAnalyticsCategoryCount) {
      return _i27.LabAnalyticsCategoryCount.fromJson(data) as T;
    }
    if (t == _i28.LabAnalyticsDailyPoint) {
      return _i28.LabAnalyticsDailyPoint.fromJson(data) as T;
    }
    if (t == _i29.LabAnalyticsShiftStat) {
      return _i29.LabAnalyticsShiftStat.fromJson(data) as T;
    }
    if (t == _i30.LabAnalyticsSnapshot) {
      return _i30.LabAnalyticsSnapshot.fromJson(data) as T;
    }
    if (t == _i31.LabAnalyticsTestCount) {
      return _i31.LabAnalyticsTestCount.fromJson(data) as T;
    }
    if (t == _i32.LabPaymentItem) {
      return _i32.LabPaymentItem.fromJson(data) as T;
    }
    if (t == _i33.LabTenHistory) {
      return _i33.LabTenHistory.fromJson(data) as T;
    }
    if (t == _i34.LabToday) {
      return _i34.LabToday.fromJson(data) as T;
    }
    if (t == _i35.LoginResponse) {
      return _i35.LoginResponse.fromJson(data) as T;
    }
    if (t == _i36.MedicineAlternative) {
      return _i36.MedicineAlternative.fromJson(data) as T;
    }
    if (t == _i37.MedicineDetail) {
      return _i37.MedicineDetail.fromJson(data) as T;
    }
    if (t == _i38.NotificationInfo) {
      return _i38.NotificationInfo.fromJson(data) as T;
    }
    if (t == _i39.OndutyStaff) {
      return _i39.OndutyStaff.fromJson(data) as T;
    }
    if (t == _i40.OtpChallengeResponse) {
      return _i40.OtpChallengeResponse.fromJson(data) as T;
    }
    if (t == _i41.PatientExternalReport) {
      return _i41.PatientExternalReport.fromJson(data) as T;
    }
    if (t == _i42.PatientPrescriptionListItem) {
      return _i42.PatientPrescriptionListItem.fromJson(data) as T;
    }
    if (t == _i43.PatientPrescribedItem) {
      return _i43.PatientPrescribedItem.fromJson(data) as T;
    }
    if (t == _i44.PatientPrescriptionDetails) {
      return _i44.PatientPrescriptionDetails.fromJson(data) as T;
    }
    if (t == _i45.PatientProfile) {
      return _i45.PatientProfile.fromJson(data) as T;
    }
    if (t == _i46.PatientReportDto) {
      return _i46.PatientReportDto.fromJson(data) as T;
    }
    if (t == _i47.LabTests) {
      return _i47.LabTests.fromJson(data) as T;
    }
    if (t == _i48.Prescription) {
      return _i48.Prescription.fromJson(data) as T;
    }
    if (t == _i49.PrescriptionDetail) {
      return _i49.PrescriptionDetail.fromJson(data) as T;
    }
    if (t == _i50.PrescriptionList) {
      return _i50.PrescriptionList.fromJson(data) as T;
    }
    if (t == _i51.LabTestRangeRow) {
      return _i51.LabTestRangeRow.fromJson(data) as T;
    }
    if (t == _i52.MedicineStockRangeRow) {
      return _i52.MedicineStockRangeRow.fromJson(data) as T;
    }
    if (t == _i53.MonthlyBreakdown) {
      return _i53.MonthlyBreakdown.fromJson(data) as T;
    }
    if (t == _i54.PrescriptionStats) {
      return _i54.PrescriptionStats.fromJson(data) as T;
    }
    if (t == _i55.StockReport) {
      return _i55.StockReport.fromJson(data) as T;
    }
    if (t == _i56.TopMedicine) {
      return _i56.TopMedicine.fromJson(data) as T;
    }
    if (t == _i57.Roster) {
      return _i57.Roster.fromJson(data) as T;
    }
    if (t == _i58.Rosterlists) {
      return _i58.Rosterlists.fromJson(data) as T;
    }
    if (t == _i59.RosterUserRole) {
      return _i59.RosterUserRole.fromJson(data) as T;
    }
    if (t == _i60.ShiftType) {
      return _i60.ShiftType.fromJson(data) as T;
    }
    if (t == _i61.StaffProfileDto) {
      return _i61.StaffProfileDto.fromJson(data) as T;
    }
    if (t == _i62.TestResult) {
      return _i62.TestResult.fromJson(data) as T;
    }
    if (t == _i63.UserListItem) {
      return _i63.UserListItem.fromJson(data) as T;
    }
    if (t == _i1.getType<_i3.InventoryCategory?>()) {
      return (data != null ? _i3.InventoryCategory.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.InventoryItemInfo?>()) {
      return (data != null ? _i4.InventoryItemInfo.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.PrescribedItem?>()) {
      return (data != null ? _i5.PrescribedItem.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.StaffInfo?>()) {
      return (data != null ? _i6.StaffInfo.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.AdminDashboardOverview?>()) {
      return (data != null ? _i7.AdminDashboardOverview.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i8.AdminProfileRespond?>()) {
      return (data != null ? _i8.AdminProfileRespond.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i9.AmbulanceContact?>()) {
      return (data != null ? _i9.AmbulanceContact.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.AppointmentRequestItem?>()) {
      return (data != null ? _i10.AppointmentRequestItem.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i11.AuditEntry?>()) {
      return (data != null ? _i11.AuditEntry.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i12.DashboardAnalytics?>()) {
      return (data != null ? _i12.DashboardAnalytics.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i13.DispenseHistoryEntry?>()) {
      return (data != null ? _i13.DispenseHistoryEntry.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i14.DispenseItemDetail?>()) {
      return (data != null ? _i14.DispenseItemDetail.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i15.DispenseItemRequest?>()) {
      return (data != null ? _i15.DispenseItemRequest.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i16.DispensedItemInput?>()) {
      return (data != null ? _i16.DispensedItemInput.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i17.DispensedItemSummary?>()) {
      return (data != null ? _i17.DispensedItemSummary.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i18.DispenserProfileR?>()) {
      return (data != null ? _i18.DispenserProfileR.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i19.DoctorHomeData?>()) {
      return (data != null ? _i19.DoctorHomeData.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i20.DoctorHomeRecentItem?>()) {
      return (data != null ? _i20.DoctorHomeRecentItem.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i21.DoctorHomeReviewedReport?>()) {
      return (data != null
              ? _i21.DoctorHomeReviewedReport.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i22.DoctorProfile?>()) {
      return (data != null ? _i22.DoctorProfile.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i23.ExternalReportFile?>()) {
      return (data != null ? _i23.ExternalReportFile.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i24.Greeting?>()) {
      return (data != null ? _i24.Greeting.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i25.InventoryAuditLog?>()) {
      return (data != null ? _i25.InventoryAuditLog.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i26.InventoryTransactionInfo?>()) {
      return (data != null
              ? _i26.InventoryTransactionInfo.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i27.LabAnalyticsCategoryCount?>()) {
      return (data != null
              ? _i27.LabAnalyticsCategoryCount.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i28.LabAnalyticsDailyPoint?>()) {
      return (data != null ? _i28.LabAnalyticsDailyPoint.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i29.LabAnalyticsShiftStat?>()) {
      return (data != null ? _i29.LabAnalyticsShiftStat.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i30.LabAnalyticsSnapshot?>()) {
      return (data != null ? _i30.LabAnalyticsSnapshot.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i31.LabAnalyticsTestCount?>()) {
      return (data != null ? _i31.LabAnalyticsTestCount.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i32.LabPaymentItem?>()) {
      return (data != null ? _i32.LabPaymentItem.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i33.LabTenHistory?>()) {
      return (data != null ? _i33.LabTenHistory.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i34.LabToday?>()) {
      return (data != null ? _i34.LabToday.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i35.LoginResponse?>()) {
      return (data != null ? _i35.LoginResponse.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i36.MedicineAlternative?>()) {
      return (data != null ? _i36.MedicineAlternative.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i37.MedicineDetail?>()) {
      return (data != null ? _i37.MedicineDetail.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i38.NotificationInfo?>()) {
      return (data != null ? _i38.NotificationInfo.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i39.OndutyStaff?>()) {
      return (data != null ? _i39.OndutyStaff.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i40.OtpChallengeResponse?>()) {
      return (data != null ? _i40.OtpChallengeResponse.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i41.PatientExternalReport?>()) {
      return (data != null ? _i41.PatientExternalReport.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i42.PatientPrescriptionListItem?>()) {
      return (data != null
              ? _i42.PatientPrescriptionListItem.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i43.PatientPrescribedItem?>()) {
      return (data != null ? _i43.PatientPrescribedItem.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i44.PatientPrescriptionDetails?>()) {
      return (data != null
              ? _i44.PatientPrescriptionDetails.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i45.PatientProfile?>()) {
      return (data != null ? _i45.PatientProfile.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i46.PatientReportDto?>()) {
      return (data != null ? _i46.PatientReportDto.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i47.LabTests?>()) {
      return (data != null ? _i47.LabTests.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i48.Prescription?>()) {
      return (data != null ? _i48.Prescription.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i49.PrescriptionDetail?>()) {
      return (data != null ? _i49.PrescriptionDetail.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i50.PrescriptionList?>()) {
      return (data != null ? _i50.PrescriptionList.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i51.LabTestRangeRow?>()) {
      return (data != null ? _i51.LabTestRangeRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i52.MedicineStockRangeRow?>()) {
      return (data != null ? _i52.MedicineStockRangeRow.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i53.MonthlyBreakdown?>()) {
      return (data != null ? _i53.MonthlyBreakdown.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i54.PrescriptionStats?>()) {
      return (data != null ? _i54.PrescriptionStats.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i55.StockReport?>()) {
      return (data != null ? _i55.StockReport.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i56.TopMedicine?>()) {
      return (data != null ? _i56.TopMedicine.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i57.Roster?>()) {
      return (data != null ? _i57.Roster.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i58.Rosterlists?>()) {
      return (data != null ? _i58.Rosterlists.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i59.RosterUserRole?>()) {
      return (data != null ? _i59.RosterUserRole.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i60.ShiftType?>()) {
      return (data != null ? _i60.ShiftType.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i61.StaffProfileDto?>()) {
      return (data != null ? _i61.StaffProfileDto.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i62.TestResult?>()) {
      return (data != null ? _i62.TestResult.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i63.UserListItem?>()) {
      return (data != null ? _i63.UserListItem.fromJson(data) : null) as T;
    }
    if (t == List<_i53.MonthlyBreakdown>) {
      return (data as List)
              .map((e) => deserialize<_i53.MonthlyBreakdown>(e))
              .toList()
          as T;
    }
    if (t == List<_i56.TopMedicine>) {
      return (data as List)
              .map((e) => deserialize<_i56.TopMedicine>(e))
              .toList()
          as T;
    }
    if (t == List<_i55.StockReport>) {
      return (data as List)
              .map((e) => deserialize<_i55.StockReport>(e))
              .toList()
          as T;
    }
    if (t == List<_i17.DispensedItemSummary>) {
      return (data as List)
              .map((e) => deserialize<_i17.DispensedItemSummary>(e))
              .toList()
          as T;
    }
    if (t == List<_i20.DoctorHomeRecentItem>) {
      return (data as List)
              .map((e) => deserialize<_i20.DoctorHomeRecentItem>(e))
              .toList()
          as T;
    }
    if (t == List<_i21.DoctorHomeReviewedReport>) {
      return (data as List)
              .map((e) => deserialize<_i21.DoctorHomeReviewedReport>(e))
              .toList()
          as T;
    }
    if (t == List<_i28.LabAnalyticsDailyPoint>) {
      return (data as List)
              .map((e) => deserialize<_i28.LabAnalyticsDailyPoint>(e))
              .toList()
          as T;
    }
    if (t == List<_i31.LabAnalyticsTestCount>) {
      return (data as List)
              .map((e) => deserialize<_i31.LabAnalyticsTestCount>(e))
              .toList()
          as T;
    }
    if (t == List<_i27.LabAnalyticsCategoryCount>) {
      return (data as List)
              .map((e) => deserialize<_i27.LabAnalyticsCategoryCount>(e))
              .toList()
          as T;
    }
    if (t == List<_i29.LabAnalyticsShiftStat>) {
      return (data as List)
              .map((e) => deserialize<_i29.LabAnalyticsShiftStat>(e))
              .toList()
          as T;
    }
    if (t == List<_i43.PatientPrescribedItem>) {
      return (data as List)
              .map((e) => deserialize<_i43.PatientPrescribedItem>(e))
              .toList()
          as T;
    }
    if (t == List<_i5.PrescribedItem>) {
      return (data as List)
              .map((e) => deserialize<_i5.PrescribedItem>(e))
              .toList()
          as T;
    }
    if (t == List<_i64.UserListItem>) {
      return (data as List)
              .map((e) => deserialize<_i64.UserListItem>(e))
              .toList()
          as T;
    }
    if (t == List<_i65.Roster>) {
      return (data as List).map((e) => deserialize<_i65.Roster>(e)).toList()
          as T;
    }
    if (t == List<_i66.Rosterlists>) {
      return (data as List)
              .map((e) => deserialize<_i66.Rosterlists>(e))
              .toList()
          as T;
    }
    if (t == List<_i67.AuditEntry>) {
      return (data as List).map((e) => deserialize<_i67.AuditEntry>(e)).toList()
          as T;
    }
    if (t == List<_i68.InventoryCategory>) {
      return (data as List)
              .map((e) => deserialize<_i68.InventoryCategory>(e))
              .toList()
          as T;
    }
    if (t == List<_i69.InventoryItemInfo>) {
      return (data as List)
              .map((e) => deserialize<_i69.InventoryItemInfo>(e))
              .toList()
          as T;
    }
    if (t == List<_i70.InventoryTransactionInfo>) {
      return (data as List)
              .map((e) => deserialize<_i70.InventoryTransactionInfo>(e))
              .toList()
          as T;
    }
    if (t == List<_i71.InventoryAuditLog>) {
      return (data as List)
              .map((e) => deserialize<_i71.InventoryAuditLog>(e))
              .toList()
          as T;
    }
    if (t == List<_i72.TopMedicine>) {
      return (data as List)
              .map((e) => deserialize<_i72.TopMedicine>(e))
              .toList()
          as T;
    }
    if (t == List<_i73.MedicineStockRangeRow>) {
      return (data as List)
              .map((e) => deserialize<_i73.MedicineStockRangeRow>(e))
              .toList()
          as T;
    }
    if (t == List<DateTime>) {
      return (data as List).map((e) => deserialize<DateTime>(e)).toList() as T;
    }
    if (t == List<_i74.LabTestRangeRow>) {
      return (data as List)
              .map((e) => deserialize<_i74.LabTestRangeRow>(e))
              .toList()
          as T;
    }
    if (t == List<_i75.Prescription>) {
      return (data as List)
              .map((e) => deserialize<_i75.Prescription>(e))
              .toList()
          as T;
    }
    if (t == List<_i76.DispenseItemRequest>) {
      return (data as List)
              .map((e) => deserialize<_i76.DispenseItemRequest>(e))
              .toList()
          as T;
    }
    if (t == List<_i77.DispenseHistoryEntry>) {
      return (data as List)
              .map((e) => deserialize<_i77.DispenseHistoryEntry>(e))
              .toList()
          as T;
    }
    if (t == Map<String, String?>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<String?>(v)),
          )
          as T;
    }
    if (t == List<_i78.PrescribedItem>) {
      return (data as List)
              .map((e) => deserialize<_i78.PrescribedItem>(e))
              .toList()
          as T;
    }
    if (t == List<_i79.PatientExternalReport>) {
      return (data as List)
              .map((e) => deserialize<_i79.PatientExternalReport>(e))
              .toList()
          as T;
    }
    if (t == List<_i80.PatientPrescriptionListItem>) {
      return (data as List)
              .map((e) => deserialize<_i80.PatientPrescriptionListItem>(e))
              .toList()
          as T;
    }
    if (t == List<_i81.AppointmentRequestItem>) {
      return (data as List)
              .map((e) => deserialize<_i81.AppointmentRequestItem>(e))
              .toList()
          as T;
    }
    if (t == List<_i82.LabTests>) {
      return (data as List).map((e) => deserialize<_i82.LabTests>(e)).toList()
          as T;
    }
    if (t == List<_i83.LabPaymentItem>) {
      return (data as List)
              .map((e) => deserialize<_i83.LabPaymentItem>(e))
              .toList()
          as T;
    }
    if (t == List<_i84.TestResult>) {
      return (data as List).map((e) => deserialize<_i84.TestResult>(e)).toList()
          as T;
    }
    if (t == List<_i85.LabTenHistory>) {
      return (data as List)
              .map((e) => deserialize<_i85.LabTenHistory>(e))
              .toList()
          as T;
    }
    if (t == List<_i86.NotificationInfo>) {
      return (data as List)
              .map((e) => deserialize<_i86.NotificationInfo>(e))
              .toList()
          as T;
    }
    if (t == Map<String, int>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<int>(v)),
          )
          as T;
    }
    if (t == List<_i87.PatientReportDto>) {
      return (data as List)
              .map((e) => deserialize<_i87.PatientReportDto>(e))
              .toList()
          as T;
    }
    if (t == List<_i88.PrescriptionList>) {
      return (data as List)
              .map((e) => deserialize<_i88.PrescriptionList>(e))
              .toList()
          as T;
    }
    if (t == List<_i89.StaffInfo>) {
      return (data as List).map((e) => deserialize<_i89.StaffInfo>(e)).toList()
          as T;
    }
    if (t == List<_i90.AmbulanceContact>) {
      return (data as List)
              .map((e) => deserialize<_i90.AmbulanceContact>(e))
              .toList()
          as T;
    }
    if (t == List<_i91.OndutyStaff>) {
      return (data as List)
              .map((e) => deserialize<_i91.OndutyStaff>(e))
              .toList()
          as T;
    }
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i3.InventoryCategory => 'InventoryCategory',
      _i4.InventoryItemInfo => 'InventoryItemInfo',
      _i5.PrescribedItem => 'PrescribedItem',
      _i6.StaffInfo => 'StaffInfo',
      _i7.AdminDashboardOverview => 'AdminDashboardOverview',
      _i8.AdminProfileRespond => 'AdminProfileRespond',
      _i9.AmbulanceContact => 'AmbulanceContact',
      _i10.AppointmentRequestItem => 'AppointmentRequestItem',
      _i11.AuditEntry => 'AuditEntry',
      _i12.DashboardAnalytics => 'DashboardAnalytics',
      _i13.DispenseHistoryEntry => 'DispenseHistoryEntry',
      _i14.DispenseItemDetail => 'DispenseItemDetail',
      _i15.DispenseItemRequest => 'DispenseItemRequest',
      _i16.DispensedItemInput => 'DispensedItemInput',
      _i17.DispensedItemSummary => 'DispensedItemSummary',
      _i18.DispenserProfileR => 'DispenserProfileR',
      _i19.DoctorHomeData => 'DoctorHomeData',
      _i20.DoctorHomeRecentItem => 'DoctorHomeRecentItem',
      _i21.DoctorHomeReviewedReport => 'DoctorHomeReviewedReport',
      _i22.DoctorProfile => 'DoctorProfile',
      _i23.ExternalReportFile => 'ExternalReportFile',
      _i24.Greeting => 'Greeting',
      _i25.InventoryAuditLog => 'InventoryAuditLog',
      _i26.InventoryTransactionInfo => 'InventoryTransactionInfo',
      _i27.LabAnalyticsCategoryCount => 'LabAnalyticsCategoryCount',
      _i28.LabAnalyticsDailyPoint => 'LabAnalyticsDailyPoint',
      _i29.LabAnalyticsShiftStat => 'LabAnalyticsShiftStat',
      _i30.LabAnalyticsSnapshot => 'LabAnalyticsSnapshot',
      _i31.LabAnalyticsTestCount => 'LabAnalyticsTestCount',
      _i32.LabPaymentItem => 'LabPaymentItem',
      _i33.LabTenHistory => 'LabTenHistory',
      _i34.LabToday => 'LabToday',
      _i35.LoginResponse => 'LoginResponse',
      _i36.MedicineAlternative => 'MedicineAlternative',
      _i37.MedicineDetail => 'MedicineDetail',
      _i38.NotificationInfo => 'NotificationInfo',
      _i39.OndutyStaff => 'OndutyStaff',
      _i40.OtpChallengeResponse => 'OtpChallengeResponse',
      _i41.PatientExternalReport => 'PatientExternalReport',
      _i42.PatientPrescriptionListItem => 'PatientPrescriptionListItem',
      _i43.PatientPrescribedItem => 'PatientPrescribedItem',
      _i44.PatientPrescriptionDetails => 'PatientPrescriptionDetails',
      _i45.PatientProfile => 'PatientProfile',
      _i46.PatientReportDto => 'PatientReportDto',
      _i47.LabTests => 'LabTests',
      _i48.Prescription => 'Prescription',
      _i49.PrescriptionDetail => 'PrescriptionDetail',
      _i50.PrescriptionList => 'PrescriptionList',
      _i51.LabTestRangeRow => 'LabTestRangeRow',
      _i52.MedicineStockRangeRow => 'MedicineStockRangeRow',
      _i53.MonthlyBreakdown => 'MonthlyBreakdown',
      _i54.PrescriptionStats => 'PrescriptionStats',
      _i55.StockReport => 'StockReport',
      _i56.TopMedicine => 'TopMedicine',
      _i57.Roster => 'Roster',
      _i58.Rosterlists => 'Rosterlists',
      _i59.RosterUserRole => 'RosterUserRole',
      _i60.ShiftType => 'ShiftType',
      _i61.StaffProfileDto => 'StaffProfileDto',
      _i62.TestResult => 'TestResult',
      _i63.UserListItem => 'UserListItem',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('backend.', '');
    }

    switch (data) {
      case _i3.InventoryCategory():
        return 'InventoryCategory';
      case _i4.InventoryItemInfo():
        return 'InventoryItemInfo';
      case _i5.PrescribedItem():
        return 'PrescribedItem';
      case _i6.StaffInfo():
        return 'StaffInfo';
      case _i7.AdminDashboardOverview():
        return 'AdminDashboardOverview';
      case _i8.AdminProfileRespond():
        return 'AdminProfileRespond';
      case _i9.AmbulanceContact():
        return 'AmbulanceContact';
      case _i10.AppointmentRequestItem():
        return 'AppointmentRequestItem';
      case _i11.AuditEntry():
        return 'AuditEntry';
      case _i12.DashboardAnalytics():
        return 'DashboardAnalytics';
      case _i13.DispenseHistoryEntry():
        return 'DispenseHistoryEntry';
      case _i14.DispenseItemDetail():
        return 'DispenseItemDetail';
      case _i15.DispenseItemRequest():
        return 'DispenseItemRequest';
      case _i16.DispensedItemInput():
        return 'DispensedItemInput';
      case _i17.DispensedItemSummary():
        return 'DispensedItemSummary';
      case _i18.DispenserProfileR():
        return 'DispenserProfileR';
      case _i19.DoctorHomeData():
        return 'DoctorHomeData';
      case _i20.DoctorHomeRecentItem():
        return 'DoctorHomeRecentItem';
      case _i21.DoctorHomeReviewedReport():
        return 'DoctorHomeReviewedReport';
      case _i22.DoctorProfile():
        return 'DoctorProfile';
      case _i23.ExternalReportFile():
        return 'ExternalReportFile';
      case _i24.Greeting():
        return 'Greeting';
      case _i25.InventoryAuditLog():
        return 'InventoryAuditLog';
      case _i26.InventoryTransactionInfo():
        return 'InventoryTransactionInfo';
      case _i27.LabAnalyticsCategoryCount():
        return 'LabAnalyticsCategoryCount';
      case _i28.LabAnalyticsDailyPoint():
        return 'LabAnalyticsDailyPoint';
      case _i29.LabAnalyticsShiftStat():
        return 'LabAnalyticsShiftStat';
      case _i30.LabAnalyticsSnapshot():
        return 'LabAnalyticsSnapshot';
      case _i31.LabAnalyticsTestCount():
        return 'LabAnalyticsTestCount';
      case _i32.LabPaymentItem():
        return 'LabPaymentItem';
      case _i33.LabTenHistory():
        return 'LabTenHistory';
      case _i34.LabToday():
        return 'LabToday';
      case _i35.LoginResponse():
        return 'LoginResponse';
      case _i36.MedicineAlternative():
        return 'MedicineAlternative';
      case _i37.MedicineDetail():
        return 'MedicineDetail';
      case _i38.NotificationInfo():
        return 'NotificationInfo';
      case _i39.OndutyStaff():
        return 'OndutyStaff';
      case _i40.OtpChallengeResponse():
        return 'OtpChallengeResponse';
      case _i41.PatientExternalReport():
        return 'PatientExternalReport';
      case _i42.PatientPrescriptionListItem():
        return 'PatientPrescriptionListItem';
      case _i43.PatientPrescribedItem():
        return 'PatientPrescribedItem';
      case _i44.PatientPrescriptionDetails():
        return 'PatientPrescriptionDetails';
      case _i45.PatientProfile():
        return 'PatientProfile';
      case _i46.PatientReportDto():
        return 'PatientReportDto';
      case _i47.LabTests():
        return 'LabTests';
      case _i48.Prescription():
        return 'Prescription';
      case _i49.PrescriptionDetail():
        return 'PrescriptionDetail';
      case _i50.PrescriptionList():
        return 'PrescriptionList';
      case _i51.LabTestRangeRow():
        return 'LabTestRangeRow';
      case _i52.MedicineStockRangeRow():
        return 'MedicineStockRangeRow';
      case _i53.MonthlyBreakdown():
        return 'MonthlyBreakdown';
      case _i54.PrescriptionStats():
        return 'PrescriptionStats';
      case _i55.StockReport():
        return 'StockReport';
      case _i56.TopMedicine():
        return 'TopMedicine';
      case _i57.Roster():
        return 'Roster';
      case _i58.Rosterlists():
        return 'Rosterlists';
      case _i59.RosterUserRole():
        return 'RosterUserRole';
      case _i60.ShiftType():
        return 'ShiftType';
      case _i61.StaffProfileDto():
        return 'StaffProfileDto';
      case _i62.TestResult():
        return 'TestResult';
      case _i63.UserListItem():
        return 'UserListItem';
    }
    className = _i2.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'InventoryCategory') {
      return deserialize<_i3.InventoryCategory>(data['data']);
    }
    if (dataClassName == 'InventoryItemInfo') {
      return deserialize<_i4.InventoryItemInfo>(data['data']);
    }
    if (dataClassName == 'PrescribedItem') {
      return deserialize<_i5.PrescribedItem>(data['data']);
    }
    if (dataClassName == 'StaffInfo') {
      return deserialize<_i6.StaffInfo>(data['data']);
    }
    if (dataClassName == 'AdminDashboardOverview') {
      return deserialize<_i7.AdminDashboardOverview>(data['data']);
    }
    if (dataClassName == 'AdminProfileRespond') {
      return deserialize<_i8.AdminProfileRespond>(data['data']);
    }
    if (dataClassName == 'AmbulanceContact') {
      return deserialize<_i9.AmbulanceContact>(data['data']);
    }
    if (dataClassName == 'AppointmentRequestItem') {
      return deserialize<_i10.AppointmentRequestItem>(data['data']);
    }
    if (dataClassName == 'AuditEntry') {
      return deserialize<_i11.AuditEntry>(data['data']);
    }
    if (dataClassName == 'DashboardAnalytics') {
      return deserialize<_i12.DashboardAnalytics>(data['data']);
    }
    if (dataClassName == 'DispenseHistoryEntry') {
      return deserialize<_i13.DispenseHistoryEntry>(data['data']);
    }
    if (dataClassName == 'DispenseItemDetail') {
      return deserialize<_i14.DispenseItemDetail>(data['data']);
    }
    if (dataClassName == 'DispenseItemRequest') {
      return deserialize<_i15.DispenseItemRequest>(data['data']);
    }
    if (dataClassName == 'DispensedItemInput') {
      return deserialize<_i16.DispensedItemInput>(data['data']);
    }
    if (dataClassName == 'DispensedItemSummary') {
      return deserialize<_i17.DispensedItemSummary>(data['data']);
    }
    if (dataClassName == 'DispenserProfileR') {
      return deserialize<_i18.DispenserProfileR>(data['data']);
    }
    if (dataClassName == 'DoctorHomeData') {
      return deserialize<_i19.DoctorHomeData>(data['data']);
    }
    if (dataClassName == 'DoctorHomeRecentItem') {
      return deserialize<_i20.DoctorHomeRecentItem>(data['data']);
    }
    if (dataClassName == 'DoctorHomeReviewedReport') {
      return deserialize<_i21.DoctorHomeReviewedReport>(data['data']);
    }
    if (dataClassName == 'DoctorProfile') {
      return deserialize<_i22.DoctorProfile>(data['data']);
    }
    if (dataClassName == 'ExternalReportFile') {
      return deserialize<_i23.ExternalReportFile>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_i24.Greeting>(data['data']);
    }
    if (dataClassName == 'InventoryAuditLog') {
      return deserialize<_i25.InventoryAuditLog>(data['data']);
    }
    if (dataClassName == 'InventoryTransactionInfo') {
      return deserialize<_i26.InventoryTransactionInfo>(data['data']);
    }
    if (dataClassName == 'LabAnalyticsCategoryCount') {
      return deserialize<_i27.LabAnalyticsCategoryCount>(data['data']);
    }
    if (dataClassName == 'LabAnalyticsDailyPoint') {
      return deserialize<_i28.LabAnalyticsDailyPoint>(data['data']);
    }
    if (dataClassName == 'LabAnalyticsShiftStat') {
      return deserialize<_i29.LabAnalyticsShiftStat>(data['data']);
    }
    if (dataClassName == 'LabAnalyticsSnapshot') {
      return deserialize<_i30.LabAnalyticsSnapshot>(data['data']);
    }
    if (dataClassName == 'LabAnalyticsTestCount') {
      return deserialize<_i31.LabAnalyticsTestCount>(data['data']);
    }
    if (dataClassName == 'LabPaymentItem') {
      return deserialize<_i32.LabPaymentItem>(data['data']);
    }
    if (dataClassName == 'LabTenHistory') {
      return deserialize<_i33.LabTenHistory>(data['data']);
    }
    if (dataClassName == 'LabToday') {
      return deserialize<_i34.LabToday>(data['data']);
    }
    if (dataClassName == 'LoginResponse') {
      return deserialize<_i35.LoginResponse>(data['data']);
    }
    if (dataClassName == 'MedicineAlternative') {
      return deserialize<_i36.MedicineAlternative>(data['data']);
    }
    if (dataClassName == 'MedicineDetail') {
      return deserialize<_i37.MedicineDetail>(data['data']);
    }
    if (dataClassName == 'NotificationInfo') {
      return deserialize<_i38.NotificationInfo>(data['data']);
    }
    if (dataClassName == 'OndutyStaff') {
      return deserialize<_i39.OndutyStaff>(data['data']);
    }
    if (dataClassName == 'OtpChallengeResponse') {
      return deserialize<_i40.OtpChallengeResponse>(data['data']);
    }
    if (dataClassName == 'PatientExternalReport') {
      return deserialize<_i41.PatientExternalReport>(data['data']);
    }
    if (dataClassName == 'PatientPrescriptionListItem') {
      return deserialize<_i42.PatientPrescriptionListItem>(data['data']);
    }
    if (dataClassName == 'PatientPrescribedItem') {
      return deserialize<_i43.PatientPrescribedItem>(data['data']);
    }
    if (dataClassName == 'PatientPrescriptionDetails') {
      return deserialize<_i44.PatientPrescriptionDetails>(data['data']);
    }
    if (dataClassName == 'PatientProfile') {
      return deserialize<_i45.PatientProfile>(data['data']);
    }
    if (dataClassName == 'PatientReportDto') {
      return deserialize<_i46.PatientReportDto>(data['data']);
    }
    if (dataClassName == 'LabTests') {
      return deserialize<_i47.LabTests>(data['data']);
    }
    if (dataClassName == 'Prescription') {
      return deserialize<_i48.Prescription>(data['data']);
    }
    if (dataClassName == 'PrescriptionDetail') {
      return deserialize<_i49.PrescriptionDetail>(data['data']);
    }
    if (dataClassName == 'PrescriptionList') {
      return deserialize<_i50.PrescriptionList>(data['data']);
    }
    if (dataClassName == 'LabTestRangeRow') {
      return deserialize<_i51.LabTestRangeRow>(data['data']);
    }
    if (dataClassName == 'MedicineStockRangeRow') {
      return deserialize<_i52.MedicineStockRangeRow>(data['data']);
    }
    if (dataClassName == 'MonthlyBreakdown') {
      return deserialize<_i53.MonthlyBreakdown>(data['data']);
    }
    if (dataClassName == 'PrescriptionStats') {
      return deserialize<_i54.PrescriptionStats>(data['data']);
    }
    if (dataClassName == 'StockReport') {
      return deserialize<_i55.StockReport>(data['data']);
    }
    if (dataClassName == 'TopMedicine') {
      return deserialize<_i56.TopMedicine>(data['data']);
    }
    if (dataClassName == 'Roster') {
      return deserialize<_i57.Roster>(data['data']);
    }
    if (dataClassName == 'Rosterlists') {
      return deserialize<_i58.Rosterlists>(data['data']);
    }
    if (dataClassName == 'RosterUserRole') {
      return deserialize<_i59.RosterUserRole>(data['data']);
    }
    if (dataClassName == 'ShiftType') {
      return deserialize<_i60.ShiftType>(data['data']);
    }
    if (dataClassName == 'StaffProfileDto') {
      return deserialize<_i61.StaffProfileDto>(data['data']);
    }
    if (dataClassName == 'TestResult') {
      return deserialize<_i62.TestResult>(data['data']);
    }
    if (dataClassName == 'UserListItem') {
      return deserialize<_i63.UserListItem>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _i2.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'backend';
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/error_utils.dart';

class EventService {
  static const String _baseUrl = 'https://api.skm-tas.com';

  static Future<Map<String, dynamic>> sendEvent({
    required String flag,
    required String companyCode,
    required String employeeId,
    required String employeeName,
    String? prCode,
    String? employeeDomain,
    required String zoneName,
    required String attendanceDate,
    required String attendanceTime,
    String? selfieImgBase64,
    String? jobId,
    String? jobName,
    String? accessToken,
    double? latitude,
    double? longitude,
    String? managerId,
    String? managerName,
  }) async {
    final body = <String, dynamic>{
      'company_code': companyCode,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'zone_name': zoneName,
      'attendance_date': attendanceDate,
      'attendance_time': attendanceTime,
    };

    if (prCode != null) body['pr_code'] = prCode;
    if (employeeDomain != null) body['employee_domain'] = employeeDomain;
    if (selfieImgBase64 != null) body['selfie_img'] = selfieImgBase64;
    if (jobId != null) body['job_id'] = jobId;
    if (jobName != null) body['job_name'] = jobName;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    // manager_id / manager_name are optional on the backend — send them
    // when the app has them, omit otherwise.
    if (managerId != null) body['manager_id'] = managerId;
    if (managerName != null) body['manager_name'] = managerName;

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) headers['Authorization'] = 'Bearer $accessToken';

    final response = await http.post(
      Uri.parse('$_baseUrl/events/${_endpoint(flag)}'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException(slowNetworkMessage),
    );

    if (response.statusCode != 200) {
      throw Exception(serverErrorMessage(response,
          fallback: "Couldn't save your attendance. Please try again."));
    }

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception(badReplyMessage);
    }

    if (data is! Map<String, dynamic>) return {};
    return data;
  }

  static String _endpoint(String flag) {
    switch (flag) {
      case 'CHECK_IN':
        return 'advance-checkin';
      case 'BREAK_IN':
        return 'advance-breakin';
      case 'BREAK_OUT':
        return 'advance-breakout';
      case 'CHECK_OUT':
        return 'advance-checkout';
      default:
        throw ArgumentError('Unknown flag: $flag');
    }
  }
}

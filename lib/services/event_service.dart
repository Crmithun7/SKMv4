import 'dart:convert';
import 'package:http/http.dart' as http;

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

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) headers['Authorization'] = 'Bearer $accessToken';

    final response = await http.post(
      Uri.parse('$_baseUrl/events/${_endpoint(flag)}'),
      headers: headers,
      body: jsonEncode(body),
    );

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Server returned an unexpected response. Please try again.');
    }

    if (response.statusCode == 200) {
      if (data is! Map<String, dynamic>) return {};
      return data;
    } else {
      throw Exception((data is Map ? data['detail'] : null) ?? 'Event submission failed');
    }
  }

  static String _endpoint(String flag) {
    switch (flag) {
      case 'CHECK_IN':
        return 'checkin';
      case 'BREAK_IN':
        return 'breakin';
      case 'BREAK_OUT':
        return 'breakout';
      case 'CHECK_OUT':
        return 'checkout';
      default:
        throw Exception('Unknown flag: $flag');
    }
  }
}

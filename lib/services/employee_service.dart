import 'dart:convert';
import 'package:http/http.dart' as http;

class EmployeeService {
  static const String _baseUrl = 'https://api.skm-tas.com';

  static Future<void> changePassword({
    required String companyCode,
    required String employeeId,
    required String oldPassword,
    required String newPassword,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/employee/change_password');

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) headers['Authorization'] = 'Bearer $accessToken';

    final response = await http.put(
      uri,
      headers: headers,
      body: jsonEncode({
        'company_code': companyCode,
        'employee_id': employeeId,
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Server returned an unexpected response. Please try again.');
    }

    if (response.statusCode == 200) return;

    throw Exception(
        (data is Map ? data['detail'] : null) ?? 'Failed to change password.');
  }
}

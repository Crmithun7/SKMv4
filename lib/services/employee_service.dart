import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/error_utils.dart';

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
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception(slowNetworkMessage),
    );

    if (response.statusCode != 200) {
      throw Exception(serverErrorMessage(response,
          fallback: "Couldn't change your password. Please try again."));
    }

  }
}

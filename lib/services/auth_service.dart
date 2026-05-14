import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/employee.dart';

class AuthService {
  static const String _baseUrl = 'https://api.skm-tas.com'; // Android emulator → localhost

  static Future<Employee> login(String loginCode, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login_code': loginCode, 'password': password}),
    );

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Server returned an unexpected response. Please try again.');
    }

    if (response.statusCode == 200) {
      if (data is! Map<String, dynamic>) {
        throw Exception('Unexpected server response. Please try again.');
      }
      return Employee.fromJson(data);
    } else if (response.statusCode == 403) {
      throw Exception((data is Map ? data['detail'] : null) ?? 'Account blocked. Contact admin.');
    } else if (response.statusCode == 401) {
      throw Exception('Invalid login code or password.');
    } else {
      throw Exception((data is Map ? data['detail'] : null) ?? 'Login failed. Try again.');
    }
  }
}

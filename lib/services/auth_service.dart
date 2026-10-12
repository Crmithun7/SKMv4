import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/error_utils.dart';
import '../models/employee.dart';

class AuthService {
  static const String _baseUrl = 'https://api.skm-tas.com'; // Android emulator → localhost

  // The SKM super admin grants each company access per application; this
  // header tells the backend the request comes from the skmv4 mobile app.
  static const Map<String, String> appHeaders = {'X-SKM-App': 'skmv4'};

  static Future<Employee> login(String loginCode, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json', ...appHeaders},
      body: jsonEncode({'login_code': loginCode, 'password': password}),
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception(slowNetworkMessage),
    );

    if (response.statusCode == 401) {
      throw Exception('Incorrect login code or password. Please check and try again.');
    }
    if (response.statusCode != 200) {
      throw Exception(serverErrorMessage(response,
          fallback: "Couldn't log you in. Please try again."));
    }

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception(badReplyMessage);
    }

    if (data is! Map<String, dynamic>) {
      throw Exception(badReplyMessage);
    }
    return Employee.fromJson(data);
  }
}

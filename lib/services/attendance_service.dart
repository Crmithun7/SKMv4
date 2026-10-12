import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/error_utils.dart';

class AttendanceService {
  static const String _baseUrl = 'https://api.skm-tas.com';

  static Future<List<Map<String, dynamic>>> getAttendanceLogs({
    required String companyCode,
    required String employeeId,
    String? date,
    String? accessToken,
  }) async {
    final queryParams = <String, String>{};
    if (date != null) queryParams['date'] = date;

    final uri = Uri.parse('$_baseUrl/events/attendance-logs/$companyCode/$employeeId')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) headers['Authorization'] = 'Bearer $accessToken';

    final response = await http.get(uri, headers: headers).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception(slowNetworkMessage),
    );

    if (response.statusCode != 200) {
      throw Exception(serverErrorMessage(response,
          fallback: "Couldn't load your attendance history. Please try again."));
    }

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception(badReplyMessage);
    }

    if (data is Map && data['success'] == true) {
      final List<dynamic> list = data['data'] ?? [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }
}

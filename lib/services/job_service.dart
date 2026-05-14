import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/job.dart';

class JobService {
  static const String _baseUrl = 'https://api.skm-tas.com';

  static Future<List<Job>> getJobsByCompany(String companyCode) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/jobs/$companyCode'),
      headers: {'Content-Type': 'application/json'},
    );

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Server returned an unexpected response. Please try again.');
    }

    if (response.statusCode == 200) {
      final List<dynamic> list = (data is Map ? data['data'] : null) ?? [];
      return list.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception((data is Map ? data['detail'] : null) ?? 'Failed to fetch jobs');
    }
  }
}

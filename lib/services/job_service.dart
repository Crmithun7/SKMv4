import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/error_utils.dart';
import '../models/job.dart';

class JobService {
  static const String _baseUrl = 'https://api.skm-tas.com';

  static Future<List<Job>> getJobsByCompany(String companyCode) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/jobs/$companyCode'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception(slowNetworkMessage),
    );

    if (response.statusCode != 200) {
      throw Exception(serverErrorMessage(response,
          fallback: "Couldn't load the job list. Please try again."));
    }

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception(badReplyMessage);
    }

    final List<dynamic> list = (data is Map ? data['data'] : null) ?? [];
    return list.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee.dart';

class StorageService {
  static const _keyEmployee    = 'employee_data';
  static const _keyCheckedIn   = 'checked_in_';
  static const _keyCheckinTime = 'checkin_time_';

  // ── Employee session ───────────────────────────────────────────────────────

  static Future<void> saveEmployee(Employee e) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmployee, jsonEncode({
        'access_token':    e.accessToken,
        'employee_id':     e.employeeId,
        'employee_name':   e.employeeName,
        'company_code':    e.companyCode,
        'company_name':    e.companyName,
        'employee_img':    e.employeeImg,
        'company_logo':    e.companyLogo,
        'roles':           e.roles,
        'permissions':     e.permissions,
        'pr_code':         e.prCode,
        'employee_domain': e.employeeDomain,
      }));
    } catch (_) {}
  }

  static Future<Employee?> getEmployee() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyEmployee);
      if (str == null) return null;
      return Employee.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearEmployee() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyEmployee);
    } catch (_) {}
  }

  // ── Attendance state ───────────────────────────────────────────────────────

  static Future<void> setCheckedIn(String employeeId, String time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_keyCheckedIn$employeeId', true);
      await prefs.setString('$_keyCheckinTime$employeeId', time);
    } catch (_) {}
  }

  static Future<bool> isCheckedIn(String employeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_keyCheckedIn$employeeId') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getCheckinTime(String employeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_keyCheckinTime$employeeId');
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCheckedIn(String employeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyCheckedIn$employeeId');
      await prefs.remove('$_keyCheckinTime$employeeId');
    } catch (_) {}
  }
}

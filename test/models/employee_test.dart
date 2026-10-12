import 'package:flutter_test/flutter_test.dart';
import 'package:skmcam/models/employee.dart';

void main() {
  group('Employee.fromJson', () {
    test('parses a full login response', () {
      final e = Employee.fromJson({
        'access_token': 'tok123',
        'employee_id': 'E1',
        'employee_name': 'Jane Doe',
        'company_code': 'SKM',
        'company_name': 'SKM Corp',
        'employee_img': 'data:image/png;base64,abc',
        'company_logo': 'data:image/png;base64,def',
        'roles': ['admin', 'user'],
        'permissions': ['read', 'write'],
        'pr_code': 'PR1',
        'employee_domain': 'engineering',
      });

      expect(e.accessToken, 'tok123');
      expect(e.employeeId, 'E1');
      expect(e.employeeName, 'Jane Doe');
      expect(e.roles, ['admin', 'user']);
      expect(e.permissions, ['read', 'write']);
      expect(e.prCode, 'PR1');
      expect(e.employeeDomain, 'engineering');
    });

    test('falls back to empty strings/lists for missing required-ish fields', () {
      final e = Employee.fromJson({});

      expect(e.accessToken, '');
      expect(e.employeeId, '');
      expect(e.employeeName, '');
      expect(e.companyCode, '');
      expect(e.companyName, '');
      expect(e.roles, isEmpty);
      expect(e.permissions, isEmpty);
      expect(e.employeeImg, isNull);
      expect(e.companyLogo, isNull);
      expect(e.prCode, isNull);
      expect(e.employeeDomain, isNull);
    });

    test('coerces non-string employee_id (e.g. an int) to a string', () {
      final e = Employee.fromJson({'employee_id': 42});
      expect(e.employeeId, '42');
    });
  });
}

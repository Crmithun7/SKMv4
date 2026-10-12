import 'package:flutter_test/flutter_test.dart';
import 'package:skmcam/models/job.dart';

void main() {
  group('Job.fromJson', () {
    test('prefers job_name when present', () {
      final job = Job.fromJson({'id': 1, 'company_code': 'SKM', 'job_name': 'Electrician'});
      expect(job.jobName, 'Electrician');
    });

    test('falls back to job_title, then title, then a generated placeholder', () {
      expect(Job.fromJson({'id': 2, 'job_title': 'Plumber'}).jobName, 'Plumber');
      expect(Job.fromJson({'id': 3, 'title': 'Welder'}).jobName, 'Welder');
      expect(Job.fromJson({'id': 4}).jobName, 'Job #4');
    });

    test('keeps the raw json for later use', () {
      final json = {'id': 5, 'job_name': 'Carpenter', 'extra_field': 'x'};
      final job = Job.fromJson(json);
      expect(job.raw, json);
    });
  });
}

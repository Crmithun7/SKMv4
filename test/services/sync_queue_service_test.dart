import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skmcam/models/pending_event.dart';
import 'package:skmcam/services/sync_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PendingEvent event(String id, {String flag = 'CHECK_IN'}) => PendingEvent(
        id: id,
        flag: flag,
        companyCode: 'ACME',
        employeeId: 'E1',
        employeeName: 'Jane Doe',
        zoneName: 'Main Site',
        attendanceDate: '2026-10-10',
        attendanceTime: '09:00:00',
        queuedAt: '2026-10-10T09:00:00.000',
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SyncQueueService', () {
    test('getAll returns an empty list when nothing is queued', () async {
      expect(await SyncQueueService.getAll(), isEmpty);
      expect(await SyncQueueService.count(), 0);
    });

    test('enqueue adds an event that getAll and count then reflect', () async {
      await SyncQueueService.enqueue(event('1'));
      final all = await SyncQueueService.getAll();
      expect(all, hasLength(1));
      expect(all.first.id, '1');
      expect(all.first.employeeId, 'E1');
      expect(await SyncQueueService.count(), 1);
    });

    test('enqueue preserves the order events were added in (FIFO)', () async {
      await SyncQueueService.enqueue(event('1', flag: 'CHECK_IN'));
      await SyncQueueService.enqueue(event('2', flag: 'CHECK_OUT'));
      final all = await SyncQueueService.getAll();
      expect(all.map((e) => e.id).toList(), ['1', '2']);
    });

    test('removeById removes only the matching event', () async {
      await SyncQueueService.enqueue(event('1'));
      await SyncQueueService.enqueue(event('2'));
      await SyncQueueService.removeById('1');
      final all = await SyncQueueService.getAll();
      expect(all.map((e) => e.id).toList(), ['2']);
      expect(await SyncQueueService.count(), 1);
    });

    test('removeById is a no-op when the id is not queued', () async {
      await SyncQueueService.enqueue(event('1'));
      await SyncQueueService.removeById('does-not-exist');
      expect(await SyncQueueService.count(), 1);
    });
  });

  group('PendingEvent', () {
    test('round-trips every field through toJson/fromJson', () {
      final e = PendingEvent(
        id: 'abc',
        flag: 'CHECK_OUT',
        companyCode: 'ACME',
        employeeId: 'E1',
        employeeName: 'Jane Doe',
        prCode: 'PR1',
        employeeDomain: 'Engineering',
        zoneName: 'Main Site',
        attendanceDate: '2026-10-10',
        attendanceTime: '18:00:00',
        selfieImgBase64: 'data:image/jpeg;base64,abc123',
        jobId: 'J1',
        jobName: 'Technician',
        accessToken: 'token123',
        latitude: 12.34,
        longitude: 56.78,
        managerId: 'M1',
        managerName: 'Manager Name',
        queuedAt: '2026-10-10T18:00:00.000',
      );

      final roundTripped = PendingEvent.fromJson(e.toJson());

      expect(roundTripped.id, e.id);
      expect(roundTripped.flag, e.flag);
      expect(roundTripped.companyCode, e.companyCode);
      expect(roundTripped.employeeId, e.employeeId);
      expect(roundTripped.employeeName, e.employeeName);
      expect(roundTripped.prCode, e.prCode);
      expect(roundTripped.employeeDomain, e.employeeDomain);
      expect(roundTripped.zoneName, e.zoneName);
      expect(roundTripped.attendanceDate, e.attendanceDate);
      expect(roundTripped.attendanceTime, e.attendanceTime);
      expect(roundTripped.selfieImgBase64, e.selfieImgBase64);
      expect(roundTripped.jobId, e.jobId);
      expect(roundTripped.jobName, e.jobName);
      expect(roundTripped.accessToken, e.accessToken);
      expect(roundTripped.latitude, e.latitude);
      expect(roundTripped.longitude, e.longitude);
      expect(roundTripped.managerId, e.managerId);
      expect(roundTripped.managerName, e.managerName);
      expect(roundTripped.queuedAt, e.queuedAt);
    });

    test('defaults optional fields to null when missing from json', () {
      final e = PendingEvent.fromJson({
        'id': '1',
        'flag': 'CHECK_IN',
        'company_code': 'ACME',
        'employee_id': 'E1',
        'employee_name': 'Jane Doe',
        'attendance_date': '2026-10-10',
        'attendance_time': '09:00:00',
      });

      expect(e.prCode, isNull);
      expect(e.selfieImgBase64, isNull);
      expect(e.latitude, isNull);
      expect(e.longitude, isNull);
      expect(e.zoneName, '');
    });
  });
}

import 'package:flutter/foundation.dart';
import 'event_service.dart';
import 'storage_service.dart';
import 'sync_queue_service.dart';
import '../models/pending_event.dart';
import '../utils/error_utils.dart';

/// How many queued events were resolved the last time [SyncService.flush]
/// ran.
class SyncFlushResult {
  final int synced;
  final int failed;
  final int remaining;
  const SyncFlushResult({required this.synced, required this.failed, required this.remaining});
}

/// Replays queued check-in/check-out events (see [SyncQueueService]) against
/// the server once connectivity is back.
///
/// Events are sent in the order they were queued, so a check-in always
/// reaches the backend before the check-out that followed it offline. The
/// first event that still can't reach the server stops the run — the rest
/// stay queued for next time. An event the server actually rejects (not a
/// connectivity problem — e.g. "already checked in") is dropped rather than
/// retried forever, since resending the same payload would only fail again.
class SyncService {
  static bool _syncing = false;

  static Future<SyncFlushResult> flush() async {
    if (_syncing) return const SyncFlushResult(synced: 0, failed: 0, remaining: 0);
    _syncing = true;
    var synced = 0;
    var failed = 0;
    try {
      var queue = await SyncQueueService.getAll();
      while (queue.isNotEmpty) {
        final event = queue.first;
        try {
          await EventService.sendEvent(
            flag: event.flag,
            companyCode: event.companyCode,
            employeeId: event.employeeId,
            employeeName: event.employeeName,
            prCode: event.prCode,
            employeeDomain: event.employeeDomain,
            zoneName: event.zoneName,
            attendanceDate: event.attendanceDate,
            attendanceTime: event.attendanceTime,
            selfieImgBase64: event.selfieImgBase64,
            jobId: event.jobId,
            jobName: event.jobName,
            accessToken: event.accessToken,
            latitude: event.latitude,
            longitude: event.longitude,
            managerId: event.managerId,
            managerName: event.managerName,
          );
          await SyncQueueService.removeById(event.id);
          synced++;
        } catch (e) {
          debugPrint('Sync flush error (${e.runtimeType}): $e');
          if (isConnectivityError(e)) break; // still offline — try again later
          // The server actually answered and rejected it; retrying the same
          // payload would just fail again, so drop it instead of looping.
          await SyncQueueService.removeById(event.id);
          failed++;
        }
        queue = await SyncQueueService.getAll();
      }
      return SyncFlushResult(synced: synced, failed: failed, remaining: queue.length);
    } finally {
      _syncing = false;
    }
  }

  /// Queues [event] locally and applies its attendance side-effect
  /// optimistically (the employee did perform the action; only the upload
  /// is pending), so the UI reflects it immediately.
  static Future<void> queue(PendingEvent event) async {
    await SyncQueueService.enqueue(event);
    if (event.flag == 'CHECK_IN') {
      await StorageService.setCheckedIn(event.employeeId, event.attendanceTime);
    } else if (event.flag == 'CHECK_OUT') {
      await StorageService.clearCheckedIn(event.employeeId);
    }
  }
}

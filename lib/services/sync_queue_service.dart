import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pending_event.dart';

/// Local, on-device queue of check-in/check-out events that failed to reach
/// the server because of connectivity, waiting to be replayed by
/// [SyncService]. Backed by shared_preferences (same store the rest of the
/// app already uses) since the queue only ever holds a handful of items at
/// once — an employee can be offline for at most a few events before they're
/// back in signal range.
class SyncQueueService {
  static const _key = 'pending_events_queue';

  static Future<List<PendingEvent>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PendingEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<PendingEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> enqueue(PendingEvent event) async {
    final events = await getAll();
    events.add(event);
    await _saveAll(events);
  }

  static Future<void> removeById(String id) async {
    final events = await getAll();
    events.removeWhere((e) => e.id == id);
    await _saveAll(events);
  }

  static Future<int> count() async => (await getAll()).length;
}

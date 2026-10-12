import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/attendance_service.dart';
import '../utils/error_utils.dart';

class HistoryScreen extends StatefulWidget {
  final Employee employee;
  const HistoryScreen({super.key, required this.employee});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _kBg      = Color(0xFF080C15);
  static const _kSurface = Color(0xFF0F1625);
  static const _kBorder  = Color(0xFF1E2D42);
  static const _kAccent  = Color(0xFF2563EB);
  static const _kSuccess = Color(0xFF10B981);
  static const _kText    = Color(0xFFF0F4FF);
  static const _kSub     = Color(0xFF8B9BB4);
  static const _kMuted   = Color(0xFF4A5568);

  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;

  // Always scoped to a single day — pulling the employee's entire history
  // on every open doesn't scale, so we default to today and let the date
  // picker narrow it to any other single day instead of ever fetching all.
  DateTime _selectedDate = DateTime.now();

  bool get _isToday => _dateToString(_selectedDate) == _dateToString(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() { _loading = true; _error = null; });
    try {
      final logs = await AttendanceService.getAttendanceLogs(
        companyCode: widget.employee.companyCode,
        employeeId: widget.employee.employeeId,
        date: _dateToString(_selectedDate),
        accessToken: widget.employee.accessToken,
      );
      if (mounted) setState(() { _logs = logs; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kAccent,
            onPrimary: Colors.white,
            surface: Color(0xFF0F1625),
            onSurface: Color(0xFFF0F4FF),
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF0F1625),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadLogs();
    }
  }

  void _resetToToday() {
    if (_isToday) return;
    setState(() => _selectedDate = DateTime.now());
    _loadLogs();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _dateToString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDisplayDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  String _dateLabel(String rawDate) {
    final now       = DateTime.now();
    final today     = _dateToString(now);
    final yesterday = _dateToString(now.subtract(const Duration(days: 1)));

    if (rawDate == today) return 'Today  •  ${_formatDisplayDate(rawDate)}';
    if (rawDate == yesterday) return 'Yesterday  •  ${_formatDisplayDate(rawDate)}';
    return _formatDisplayDate(rawDate);
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$dh:$m $period';
  }

  Color _flagColor(String flag) => switch (flag) {
    'CHECK_IN'  => const Color(0xFF10B981),
    'CHECK_OUT' => const Color(0xFF2563EB),
    'BREAK_IN'  => const Color(0xFFFF6D00),
    'BREAK_OUT' => const Color(0xFF6C63FF),
    _           => _kSub,
  };

  String _flagLabel(String flag) => switch (flag) {
    'CHECK_IN'  => 'Check In',
    'CHECK_OUT' => 'Check Out',
    'BREAK_IN'  => 'Break In',
    'BREAK_OUT' => 'Break Out',
    _           => flag,
  };

  IconData _flagIcon(String flag) => switch (flag) {
    'CHECK_IN'  => Icons.login_rounded,
    'CHECK_OUT' => Icons.logout_rounded,
    'BREAK_IN'  => Icons.free_breakfast_outlined,
    'BREAK_OUT' => Icons.keyboard_return_rounded,
    _           => Icons.event_note_rounded,
  };

  Uint8List? _decodeSelfie(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString();
    if (str.isEmpty) return null;
    try {
      return base64Decode(str.split(',').last);
    } catch (_) {
      return null;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E2D42)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.history_rounded, color: _kAccent, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Attendance History',
              style: TextStyle(
                color: _kText,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: _kSub, size: 22),
            tooltip: 'Filter by date',
            onPressed: _pickDate,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  // ── Filter bar ─────────────────────────────────────────────────────────────

  Widget _filterBar() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, color: _kMuted, size: 16),
          const SizedBox(width: 8),
          const Text('Showing:', style: TextStyle(color: _kMuted, fontSize: 12)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kAccent.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _dateLabel(_dateToString(_selectedDate)),
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!_isToday) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _resetToToday,
                    child: const Icon(Icons.close_rounded, color: _kAccent, size: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Body states ────────────────────────────────────────────────────────────

  Widget _body() {
    if (_loading) return _loadingView();
    if (_error != null) return _errorView();
    if (_logs.isEmpty) return _emptyView();
    return RefreshIndicator(
      color: _kAccent,
      backgroundColor: _kSurface,
      onRefresh: _loadLogs,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _logs.length,
        itemBuilder: (ctx, i) => _logCard(_logs[i]),
      ),
    );
  }

  Widget _loadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _kAccent, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Loading history…', style: TextStyle(color: _kMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  color: Color(0xFFEF4444), size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              "Couldn't load your history",
              style: TextStyle(color: _kText, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            _retryButton(),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _kSurface,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder),
              ),
              child: Icon(
                Icons.event_busy_rounded,
                color: _kMuted,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Records Found',
              style: TextStyle(color: _kText, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _isToday
                  ? 'No attendance records for today.'
                  : 'No attendance records for ${_formatDisplayDate(_dateToString(_selectedDate))}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kMuted, fontSize: 13, height: 1.5),
            ),
            if (!_isToday) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _resetToToday,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Back to Today',
                      style: TextStyle(color: _kAccent, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _retryButton() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loadLogs,
          borderRadius: BorderRadius.circular(14),
          child: const Center(
            child: Text(
              'Try Again',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  // ── Log card ──────────────────────────────────────────────────────────────

  Widget _logCard(Map<String, dynamic> log) {
    final flag    = (log['flag'] ?? '').toString();
    final timeStr = _formatTime(log['attendance_time']?.toString());
    final zone     = (log['zone_name'] ?? '').toString();
    final working  = log['total_working_hours']?.toString();
    final breaking = log['total_break_hours']?.toString();
    final selfie   = _decodeSelfie(log['selfie_img']);
    final color    = _flagColor(flag);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top row: flag badge + time + selfie ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flag badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_flagIcon(flag), color: color, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        _flagLabel(flag),
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Time
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                if (selfie != null) ...[
                  const SizedBox(width: 12),
                  // Selfie thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      selfie,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────────
          Divider(height: 1, color: _kBorder),

          // ── Bottom row: location + stats ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone/Location
                if (zone.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 14, color: _kMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          zone,
                          style: const TextStyle(
                            color: _kSub,
                            fontSize: 12,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                // Working + Break hours
                if (working != null || breaking != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (working != null)
                        _statChip(Icons.schedule_rounded, working, _kSuccess),
                      if (working != null && breaking != null)
                        const SizedBox(width: 8),
                      if (breaking != null)
                        _statChip(Icons.free_breakfast_outlined, breaking,
                            const Color(0xFFFF6D00)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/storage_service.dart';
import '../services/sync_queue_service.dart';
import '../services/sync_service.dart';
import 'event_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final Employee employee;
  const HomeScreen({super.key, required this.employee});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _kBg      = Color(0xFF080C15);
  static const _kSurface = Color(0xFF0F1625);
  static const _kHigh    = Color(0xFF152035);
  static const _kBorder  = Color(0xFF1E2D42);
  static const _kAccent  = Color(0xFF2563EB);
  static const _kSuccess = Color(0xFF10B981);
  static const _kText    = Color(0xFFF0F4FF);
  static const _kSub     = Color(0xFF8B9BB4);
  static const _kMuted   = Color(0xFF4A5568);

  bool _isCheckedIn = false;
  String? _checkinTime;
  Uint8List? _decodedCompanyLogo;
  Uint8List? _decodedEmployeeImg;
  int _pendingSyncCount = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _decodeImages();
    _loadAttendanceState();
    _refreshPendingCount();
    _trySync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Signal can come back while the app is backgrounded (phone picks up
    // Wi-Fi again, airplane mode turned off) — catch up as soon as the
    // employee returns to the app instead of waiting for their next action.
    if (state == AppLifecycleState.resumed) _trySync();
  }

  Future<void> _refreshPendingCount() async {
    final count = await SyncQueueService.count();
    if (mounted) setState(() => _pendingSyncCount = count);
  }

  Future<void> _trySync() async {
    if (_syncing) return;
    final before = await SyncQueueService.count();
    if (before == 0) return;
    if (mounted) setState(() => _syncing = true);
    try {
      await SyncService.flush();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
    await _refreshPendingCount();
    if (mounted) await _loadAttendanceState();
  }

  void _decodeImages() {
    final logo = widget.employee.companyLogo;
    if (logo != null) {
      try { _decodedCompanyLogo = base64Decode(logo.split(',').last); } catch (_) {}
    }
    final img = widget.employee.employeeImg;
    if (img != null) {
      try { _decodedEmployeeImg = base64Decode(img.split(',').last); } catch (_) {}
    }
  }

  Future<void> _loadAttendanceState() async {
    final checked = await StorageService.isCheckedIn(widget.employee.employeeId);
    final time    = await StorageService.getCheckinTime(widget.employee.employeeId);
    if (mounted) setState(() { _isCheckedIn = checked; _checkinTime = time; });
  }

  Future<void> _openAttendance() async {
    final flag   = _isCheckedIn ? 'CHECK_OUT' : 'CHECK_IN';
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EventScreen(employee: widget.employee, flag: flag),
      ),
    );
    if (result != null) {
      _loadAttendanceState();
      _refreshPendingCount();
      _trySync();
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(employee: widget.employee)),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoryScreen(employee: widget.employee)),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatTime(String hms) {
    final parts = hms.split(':');
    if (parts.length < 2) return hms;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$displayH:$m $period';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            children: [
              // Greeting row
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()},',
                      style: const TextStyle(color: _kSub, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.employee.employeeName.split(' ').first,
                      style: const TextStyle(
                        color: _kText,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _profileCard(),
              if (_pendingSyncCount > 0) ...[
                const SizedBox(height: 16),
                _pendingSyncBanner(),
              ],
              const SizedBox(height: 16),
              _statusCard(),
              const SizedBox(height: 16),
              _actionButton(),
              const SizedBox(height: 14),
              _historyLink(),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _kBorder),
      ),
      title: Row(
        children: [
          GestureDetector(
            onTap: _openProfile,
            child: _companyLogoWidget(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employee.companyName,
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'SKM Attendance',
                  style: TextStyle(color: _kMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: _kSub, size: 22),
          tooltip: 'Attendance History',
          onPressed: _openHistory,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _companyLogoWidget() {
    if (_decodedCompanyLogo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.memory(_decodedCompanyLogo!, width: 36, height: 36, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.business_rounded, size: 18, color: _kAccent),
    );
  }

  // ── Profile card ──────────────────────────────────────────────────────────

  Widget _profileCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with gradient ring
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow halo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kAccent.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Gradient ring
              Container(
                width: 106,
                height: 106,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 47,
                  backgroundColor: _kHigh,
                  backgroundImage: _decodedEmployeeImg != null
                      ? MemoryImage(_decodedEmployeeImg!)
                      : null,
                  child: _decodedEmployeeImg == null
                      ? Icon(Icons.person_rounded, size: 50, color: _kMuted)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Name
          Text(
            widget.employee.employeeName,
            style: const TextStyle(
              color: _kText,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // ID chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _kHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fingerprint_rounded, size: 14, color: _kMuted),
                const SizedBox(width: 6),
                Text(
                  widget.employee.employeeId,
                  style: const TextStyle(color: _kSub, fontSize: 13, letterSpacing: 0.2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Text(
            widget.employee.companyName,
            style: const TextStyle(color: _kMuted, fontSize: 13),
          ),

          if (widget.employee.roles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.employee.roles.first,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Pending sync banner ───────────────────────────────────────────────────

  Widget _pendingSyncBanner() {
    const warning = Color(0xFFF59E0B);
    final label = _pendingSyncCount == 1
        ? '1 attendance record saved offline'
        : '$_pendingSyncCount attendance records saved offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: warning, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                const Text('Will sync automatically once you have internet',
                    style: TextStyle(color: _kMuted, fontSize: 11)),
              ],
            ),
          ),
          if (_syncing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: warning),
            )
          else
            GestureDetector(
              onTap: _trySync,
              child: const Icon(Icons.refresh_rounded, color: warning, size: 20),
            ),
        ],
      ),
    );
  }

  // ── Status card ───────────────────────────────────────────────────────────

  Widget _statusCard() {
    final isIn      = _isCheckedIn;
    final iconColor = isIn ? _kSuccess : _kMuted;
    final labelColor = isIn ? _kSuccess : _kSub;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isIn ? _kSuccess.withValues(alpha: 0.28) : _kBorder,
        ),
        boxShadow: isIn
            ? [
                BoxShadow(
                  color: _kSuccess.withValues(alpha: 0.07),
                  blurRadius: 24,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.1),
              border: Border.all(color: iconColor.withValues(alpha: 0.25)),
            ),
            child: Icon(
              isIn ? Icons.check_rounded : Icons.schedule_rounded,
              color: iconColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIn ? 'Checked In' : 'Not Checked In',
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isIn && _checkinTime != null
                      ? 'Since ${_formatTime(_checkinTime!)}'
                      : 'Tap below to record attendance',
                  style: const TextStyle(color: _kMuted, fontSize: 13),
                ),
              ],
            ),
          ),

          // Status dot with optional glow
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor,
              boxShadow: isIn
                  ? [
                      BoxShadow(
                        color: _kSuccess.withValues(alpha: 0.55),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
          ),
        ],
      ),
    );
  }

  // ── Action button ─────────────────────────────────────────────────────────

  Widget _actionButton() {
    final isIn = _isCheckedIn;
    final gradient = isIn
        ? const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final glowColor = isIn ? _kAccent : _kSuccess;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.42),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openAttendance,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isIn ? Icons.logout_rounded : Icons.login_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                isIn ? 'CHECK OUT' : 'CHECK IN',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── History link ──────────────────────────────────────────────────────────

  Widget _historyLink() {
    return GestureDetector(
      onTap: _openHistory,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.history_rounded, size: 15, color: Color(0xFF4A5568)),
          SizedBox(width: 6),
          Text(
            'View Attendance History',
            style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

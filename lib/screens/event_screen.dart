import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/employee.dart';
import '../models/job.dart';
import '../models/pending_event.dart';
import '../models/zone.dart';
import '../services/event_service.dart';
import '../services/job_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/zone_service.dart';
import '../utils/error_utils.dart';
import 'camera_screen.dart';

enum _LocStatus { idle, fetching, success, error, denied, permanentlyDenied, serviceDisabled }

class EventScreen extends StatefulWidget {
  final Employee employee;
  final String flag;
  const EventScreen({super.key, required this.employee, required this.flag});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  static const _kBg      = Color(0xFF080C15);
  static const _kSurface = Color(0xFF0F1625);
  static const _kHigh    = Color(0xFF152035);
  static const _kBorder  = Color(0xFF1E2D42);
  static const _kAccent  = Color(0xFF2563EB);
  static const _kSuccess = Color(0xFF10B981);
  static const _kWarning = Color(0xFFF59E0B);
  static const _kText    = Color(0xFFF0F4FF);
  static const _kSub     = Color(0xFF8B9BB4);
  static const _kMuted   = Color(0xFF4A5568);

  // Location
  _LocStatus _locStatus = _LocStatus.idle;
  String _address = '';
  double? _lat, _lng;

  // Selfie
  String? _selfiePath;

  // Jobs
  List<Job> _jobs = [];
  Job? _selectedJob;
  bool _jobsLoading = false;
  String? _jobsError;

  // Zones (for resolving zone_name / project_name from GPS)
  List<Zone> _zones = [];
  bool _zonesLoaded = false;
  // Zone control: the company only allows check-in / check-out inside a zone.
  bool _restrictToZones = false;

  // Submit
  bool _submitting = false;

  // Live clock
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  bool get _showJobs => widget.flag == 'CHECK_IN' || widget.flag == 'CHECK_OUT';
  bool get _selfieRequired => _showJobs;
  bool get _mustBeInZone => _restrictToZones && _showJobs;

  /// The zone the employee is standing in right now, if any.
  Zone? get _currentZone =>
      _locStatus == _LocStatus.success && _lat != null && _lng != null
          ? ZoneService.matchZone(_zones, _lat!, _lng!)
          : null;

  /// Why zone control blocks this check-in / check-out, or null if allowed.
  String? get _zoneProblem {
    if (!_mustBeInZone) return null;
    if (_locStatus != _LocStatus.success || _lat == null || _lng == null) {
      return 'Your location is needed. Your company only allows check-in and '
          'check-out inside a work zone. Turn on location (GPS) and try again.';
    }
    if (_zones.isEmpty) {
      return 'Your company only allows check-in and check-out inside a work '
          'zone, but no work zones are set up yet. Please contact your admin.';
    }
    if (_currentZone == null) {
      return 'You are outside your work zone. Check-in and check-out are only '
          'allowed inside a work zone. Please move inside the zone and try again.';
    }
    return null;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) { if (mounted) setState(() => _now = DateTime.now()); },
    );
    _initLocation();
    if (_showJobs) _fetchJobs();
    _fetchZones();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _locStatus = _LocStatus.serviceDisabled);
        _showLocationServiceDialog();
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return;

    if (permission == LocationPermission.denied) {
      setState(() => _locStatus = _LocStatus.denied);
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _locStatus = _LocStatus.permanentlyDenied);
      return;
    }

    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    if (mounted) setState(() => _locStatus = _LocStatus.fetching);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      String address =
          '${pos.latitude.toStringAsFixed(5)}°, ${pos.longitude.toStringAsFixed(5)}°';

      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if (p.street != null && p.street!.isNotEmpty) p.street!,
            if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
            if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
            if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
              p.administrativeArea!,
            if (p.country != null && p.country!.isNotEmpty) p.country!,
          ];
          if (parts.isNotEmpty) address = parts.join(', ');
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _address = address;
          _locStatus = _LocStatus.success;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _locStatus = _LocStatus.error);
    }
  }

  void _showLocationServiceDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: _kSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: _kAccent, size: 22),
              SizedBox(width: 10),
              Text('GPS Disabled', style: TextStyle(color: _kText, fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: const Text(
            'Location services are off. Enable GPS to record your attendance location accurately.',
            style: TextStyle(color: _kSub, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Anyway', style: TextStyle(color: _kMuted)),
            ),
            _dialogButton(
              'Enable GPS',
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openLocationSettings();
                _initLocation();
              },
            ),
          ],
        ),
      );
    });
  }

  // ── Jobs ──────────────────────────────────────────────────────────────────

  Future<void> _fetchJobs() async {
    if (mounted) setState(() { _jobsLoading = true; _jobsError = null; });
    try {
      final jobs = await JobService.getJobsByCompany(widget.employee.companyCode);
      if (mounted) setState(() { _jobs = jobs; _jobsLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _jobsError = friendlyError(e);
          _jobsLoading = false;
        });
      }
    }
  }

  // ── Zones ─────────────────────────────────────────────────────────────────

  /// Best-effort: loads the company's geofence zones so we can resolve the
  /// GPS point to a real zone_name (and therefore project_name) at submit
  /// time, plus its zone control switch. Failure here is silent — _submit()
  /// just falls back to the reverse-geocoded address (the backend still
  /// enforces zone control).
  Future<void> _fetchZones() async {
    try {
      final setup = await ZoneService.getZoneSetup(widget.employee.companyCode);
      if (mounted) {
        setState(() {
          _zones = setup.zones;
          _restrictToZones = setup.restrictToZones;
          _zonesLoaded = true;
        });
      }
    } catch (_) {}
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<void> _openCamera() async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (path != null && mounted) setState(() => _selfiePath = path);
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selfieRequired && _selfiePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Please capture a selfie before submitting',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFFB45309),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }

    // Zone control: check-in / check-out only inside one of the company's zones.
    if (_showJobs && !_zonesLoaded) await _fetchZones();
    if (!mounted) return;
    final zoneProblem = _zoneProblem;
    if (zoneProblem != null) {
      _showErrorSnack(zoneProblem);
      return;
    }

    if (_locStatus != _LocStatus.success) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _kSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _kWarning, size: 22),
              SizedBox(width: 10),
              Text('No Location', style: TextStyle(color: _kText, fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: const Text(
            '"Unknown Location" will be recorded because your location could not be fetched. Continue?',
            style: TextStyle(color: _kSub, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: _kMuted)),
            ),
            _dialogButton('Continue', onPressed: () => Navigator.pop(context, true)),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _submitting = true);

    // Replay any earlier offline check-in/check-out first, so this one
    // reaches the backend in the right order behind it.
    await SyncService.flush();

    String? selfieBase64;
    if (_selfiePath != null) {
      final bytes = await File(_selfiePath!).readAsBytes();
      selfieBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    final now  = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    // Resolve the GPS point to a configured geofence zone (so the backend
    // can look up its linked project) — falls back to the reverse-geocoded
    // address when there's no matching zone or zones failed to load.
    Zone? matchedZone;
    if (_locStatus == _LocStatus.success && _lat != null && _lng != null) {
      if (_zones.isEmpty) await _fetchZones();
      matchedZone = ZoneService.matchZone(_zones, _lat!, _lng!);
    }
    final zoneName = matchedZone?.zoneName ??
        (_locStatus == _LocStatus.success ? _address : 'Unknown Location');

    try {
      final result = await EventService.sendEvent(
        flag: widget.flag,
        companyCode: widget.employee.companyCode,
        employeeId: widget.employee.employeeId,
        employeeName: widget.employee.employeeName,
        prCode: widget.employee.prCode,
        employeeDomain: _selectedJob?.jobName ?? widget.employee.employeeDomain,
        zoneName: zoneName,
        attendanceDate: date,
        attendanceTime: time,
        selfieImgBase64: selfieBase64,
        jobId: _selectedJob?.id?.toString(),
        jobName: _selectedJob?.jobName,
        accessToken: widget.employee.accessToken,
        latitude: _lat,
        longitude: _lng,
      );

      if (mounted) {
        if (widget.flag == 'CHECK_IN') {
          await StorageService.setCheckedIn(widget.employee.employeeId, time);
        } else if (widget.flag == 'CHECK_OUT') {
          await StorageService.clearCheckedIn(widget.employee.employeeId);
        }
        setState(() => _submitting = false);
        _showSuccessDialog(result);
      }
    } catch (e) {
      debugPrint('Event submit error (${e.runtimeType}): $e');
      if (!isConnectivityError(e)) {
        if (mounted) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      friendlyError(e),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFB91C1C),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
          );
        }
        return;
      }

      // No signal / server unreachable — save it locally and sync later
      // instead of making the employee lose their check-in/check-out.
      await SyncService.queue(PendingEvent(
        id: '${widget.employee.employeeId}_${now.millisecondsSinceEpoch}',
        flag: widget.flag,
        companyCode: widget.employee.companyCode,
        employeeId: widget.employee.employeeId,
        employeeName: widget.employee.employeeName,
        prCode: widget.employee.prCode,
        employeeDomain: _selectedJob?.jobName ?? widget.employee.employeeDomain,
        zoneName: zoneName,
        attendanceDate: date,
        attendanceTime: time,
        selfieImgBase64: selfieBase64,
        jobId: _selectedJob?.id?.toString(),
        jobName: _selectedJob?.jobName,
        accessToken: widget.employee.accessToken,
        latitude: _lat,
        longitude: _lng,
        queuedAt: now.toIso8601String(),
      ));

      if (mounted) {
        setState(() => _submitting = false);
        _showQueuedDialog();
      }
    }
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wrong_location_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFB91C1C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _showQueuedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kWarning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, color: _kWarning, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$_flagLabel Saved Offline',
                style: const TextStyle(color: _kText, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          "No internet connection right now. Your check-in/out has been "
          'saved on this phone and will be sent automatically as soon as '
          "you're back online. Don't uninstall the app or clear its data "
          'until it syncs.',
          style: TextStyle(color: _kSub, height: 1.5),
        ),
        actions: [
          _dialogButton(
            'OK',
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, widget.flag);
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _flagColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: _flagColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$_flagLabel Successful!',
                style: const TextStyle(color: _kText, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                children: [
                  if (result['total_working_hours'] != null)
                    _dialogRow(Icons.work_history_rounded, 'Working Hours',
                        result['total_working_hours'].toString()),
                  if (result['total_break_hours'] != null)
                    _dialogRow(Icons.coffee_rounded, 'Break Hours',
                        result['total_break_hours'].toString()),
                  if (result['project_name'] != null)
                    _dialogRow(Icons.apartment_rounded, 'Project',
                        result['project_name'].toString()),
                  _dialogRow(
                    Icons.location_on_rounded,
                    'Location',
                    (result['zone_name']?.toString().trim().isNotEmpty ?? false)
                        ? result['zone_name'].toString()
                        : (_locStatus == _LocStatus.success ? _address : 'Unknown Location'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _dialogButton(
            'Done',
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, widget.flag);
            },
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: _kMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: _kMuted, fontSize: 11)),
                  const SizedBox(height: 1),
                  Text(value, style: const TextStyle(color: _kText, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _dialogButton(String label, {required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_flagColor, Color.lerp(_flagColor, Colors.black, 0.3)!],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextButton(
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Flag helpers ──────────────────────────────────────────────────────────

  ({String label, Color color, IconData icon}) get _flagMeta => switch (widget.flag) {
    'CHECK_IN'  => (label: 'Check In',  color: _kSuccess,                  icon: Icons.login_rounded),
    'BREAK_IN'  => (label: 'Break In',  color: const Color(0xFFFF6D00),    icon: Icons.free_breakfast_outlined),
    'BREAK_OUT' => (label: 'Break Out', color: const Color(0xFF6C63FF),    icon: Icons.keyboard_return_rounded),
    _           => (label: 'Check Out', color: _kAccent,                   icon: Icons.logout_rounded),
  };

  String   get _flagLabel => _flagMeta.label;
  Color    get _flagColor => _flagMeta.color;
  IconData get _flagIcon  => _flagMeta.icon;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
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
                color: _flagColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_flagIcon, color: _flagColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              _flagLabel,
              style: const TextStyle(
                color: _kText,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dateTimeCard(),
            const SizedBox(height: 14),
            _locationCard(),
            const SizedBox(height: 14),
            _selfieCard(),
            if (_showJobs) ...[
              const SizedBox(height: 14),
              _jobCard(),
            ],
            const SizedBox(height: 24),
            _submitButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Date & Time card ──────────────────────────────────────────────────────

  Widget _dateTimeCard() {
    const days   = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName   = days[_now.weekday - 1];
    final monthName = months[_now.month - 1];
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    final ss = _now.second.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _flagColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: _flagColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Clock icon container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _flagColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.access_time_rounded, color: _flagColor, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$hh:$mm',
                    style: TextStyle(
                      color: _flagColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ':$ss',
                    style: TextStyle(
                      color: _flagColor.withValues(alpha: 0.5),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$dayName, ${_now.day} $monthName ${_now.year}',
                style: const TextStyle(color: _kSub, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Location card ─────────────────────────────────────────────────────────

  Color get _locBorderColor {
    if (_locStatus == _LocStatus.success) return _kSuccess.withValues(alpha: 0.28);
    if (_locStatus == _LocStatus.error ||
        _locStatus == _LocStatus.denied ||
        _locStatus == _LocStatus.permanentlyDenied ||
        _locStatus == _LocStatus.serviceDisabled) {
      return const Color(0xFFEF4444).withValues(alpha: 0.28);
    }
    return _kBorder;
  }

  Widget _locationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _locBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_on_rounded, color: _kAccent, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'LOCATION',
                style: TextStyle(
                  color: _kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _locationContent(),
        ],
      ),
    );
  }

  Widget _locationContent() {
    switch (_locStatus) {
      case _LocStatus.idle:
      case _LocStatus.fetching:
        return const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent),
            ),
            SizedBox(width: 12),
            Text('Fetching your location…', style: TextStyle(color: _kSub, fontSize: 13)),
          ],
        );

      case _LocStatus.success:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _kSuccess.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: _kSuccess, size: 12),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_address, style: const TextStyle(color: _kText, fontSize: 13, height: 1.4)),
                ),
              ],
            ),
            if (_lat != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'lat: ${_lat!.toStringAsFixed(6)}, lng: ${_lng!.toStringAsFixed(6)}',
                  style: const TextStyle(color: _kMuted, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
            if (_mustBeInZone) ...[
              const SizedBox(height: 10),
              _zoneStatusChip(),
            ],
          ],
        );

      case _LocStatus.error:
        return Row(
          children: [
            const Icon(Icons.location_off_rounded, color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text("Couldn't find your location. Move to an open area and tap Retry.",
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
            ),
            TextButton(
              onPressed: _fetchLocation,
              child: const Text('Retry', style: TextStyle(color: _kAccent, fontSize: 13)),
            ),
          ],
        );

      case _LocStatus.denied:
        return _permissionBanner(
          'Location access is needed to record where you check in. Tap below to allow it.',
          actionLabel: 'Grant Permission',
          onAction: _initLocation,
        );

      case _LocStatus.permanentlyDenied:
        return _permissionBanner(
          'Location access is turned off for this app. Open Settings and allow location access.',
          actionLabel: 'Open App Settings',
          onAction: () async {
            await Geolocator.openAppSettings();
            _initLocation();
          },
        );

      case _LocStatus.serviceDisabled:
        return _permissionBanner(
          "Your phone's location (GPS) is turned off. Please turn it on to continue.",
          actionLabel: 'Enable GPS',
          onAction: () async {
            await Geolocator.openLocationSettings();
            _initLocation();
          },
        );
    }
  }

  /// Zone control status under the location: inside which zone, or outside.
  Widget _zoneStatusChip() {
    final zone = _currentZone;
    final inside = zone != null;
    final color = inside ? _kSuccess : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(inside ? Icons.verified_rounded : Icons.wrong_location_rounded,
              color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              inside
                  ? 'Inside work zone: ${zone.zoneName}'
                  : 'Outside your work zone. Check-in and check-out are only allowed inside a zone.',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionBanner(String msg,
      {required String actionLabel, required VoidCallback onAction}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _kWarning, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg, style: const TextStyle(color: _kWarning, fontSize: 13))),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(color: _kAccent, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // ── Selfie card ───────────────────────────────────────────────────────────

  Widget _selfieCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: _kAccent, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _selfieRequired ? 'SELFIE *' : 'SELFIE',
                      style: const TextStyle(
                        color: _kAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                if (_selfiePath != null)
                  GestureDetector(
                    onTap: _openCamera,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 14, color: _kSub),
                          SizedBox(width: 5),
                          Text('Retake', style: TextStyle(color: _kSub, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openCamera,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: _selfiePath != null
                  ? Image.file(
                      File(_selfiePath!),
                      width: double.infinity,
                      height: 280,
                      fit: BoxFit.cover,
                    )
                  : _selfiePlaceholder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selfiePlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      color: const Color(0xFF060A12),
      child: Stack(
        children: [
          // Viewfinder corner brackets
          ..._viewfinderCorners(),
          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 48,
                  color: _flagColor.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap to capture selfie',
                  style: TextStyle(color: _kSub, fontSize: 13),
                ),
                if (_selfieRequired) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Required',
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _viewfinderCorners() {
    const size = 22.0;
    const thick = 2.0;
    final c = _flagColor;

    return [
      Positioned(top: 18, left: 18,
          child: _corner(c, size, thick, top: true, left: true)),
      Positioned(top: 18, right: 18,
          child: _corner(c, size, thick, top: true, left: false)),
      Positioned(bottom: 18, left: 18,
          child: _corner(c, size, thick, top: false, left: true)),
      Positioned(bottom: 18, right: 18,
          child: _corner(c, size, thick, top: false, left: false)),
    ];
  }

  Widget _corner(Color c, double size, double thick,
      {required bool top, required bool left}) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top:    top  ? BorderSide(color: c, width: thick) : BorderSide.none,
            bottom: !top ? BorderSide(color: c, width: thick) : BorderSide.none,
            left:   left  ? BorderSide(color: c, width: thick) : BorderSide.none,
            right:  !left ? BorderSide(color: c, width: thick) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Job card ──────────────────────────────────────────────────────────────

  Widget _jobCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.work_outline_rounded, color: _kAccent, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'JOB',
                style: TextStyle(
                  color: _kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              const Text('Optional', style: TextStyle(color: _kMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),
          if (_jobsLoading)
            const Center(
              child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2.5),
            )
          else if (_jobsError != null)
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_jobsError!,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12))),
                TextButton(
                  onPressed: _fetchJobs,
                  child: const Text('Retry', style: TextStyle(color: _kAccent)),
                ),
              ],
            )
          else if (_jobs.isEmpty)
            const Text('No jobs available', style: TextStyle(color: _kMuted, fontSize: 13))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: _kHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: DropdownButton<Job>(
                value: _selectedJob,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                dropdownColor: _kSurface,
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kSub),
                hint: const Text('Select a job',
                    style: TextStyle(color: _kMuted, fontSize: 13)),
                items: _jobs
                    .map((job) => DropdownMenuItem<Job>(
                          value: job,
                          child: Text(job.jobName,
                              style: const TextStyle(color: _kText, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (job) => setState(() => _selectedJob = job),
              ),
            ),
        ],
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────

  Widget _submitButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: _submitting
            ? null
            : LinearGradient(
                colors: [_flagColor, Color.lerp(_flagColor, Colors.black, 0.28)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: _submitting ? _kHigh : null,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _submitting
            ? []
            : [
                BoxShadow(
                  color: _flagColor.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _submitting ? null : _submit,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_submitting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              else
                Icon(_flagIcon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                _submitting ? 'Submitting…' : 'Submit $_flagLabel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

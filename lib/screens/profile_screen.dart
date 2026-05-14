import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/employee_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Employee employee;
  const ProfileScreen({super.key, required this.employee});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _kBg      = Color(0xFF080C15);
  static const _kSurface = Color(0xFF0F1625);
  static const _kHigh    = Color(0xFF152035);
  static const _kBorder  = Color(0xFF1E2D42);
  static const _kAccent  = Color(0xFF2563EB);
  static const _kText    = Color(0xFFF0F4FF);
  static const _kSub     = Color(0xFF8B9BB4);
  static const _kMuted   = Color(0xFF4A5568);

  Uint8List? _decodedEmployeeImg;
  Uint8List? _decodedCompanyLogo;

  @override
  void initState() {
    super.initState();
    _decodeImages();
  }

  void _decodeImages() {
    final img = widget.employee.employeeImg;
    if (img != null) {
      try { _decodedEmployeeImg = base64Decode(img.split(',').last); } catch (_) {}
    }
    final logo = widget.employee.companyLogo;
    if (logo != null) {
      try { _decodedCompanyLogo = base64Decode(logo.split(',').last); } catch (_) {}
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(color: _kText, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: _kSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _kMuted)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign Out',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await StorageService.clearEmployee();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _openChangePassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(employee: widget.employee),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kText, size: 20),
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
              child: const Icon(Icons.person_rounded, color: _kAccent, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'My Profile',
              style: TextStyle(
                  color: _kText, fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ],
        ),
        actions: const [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          children: [
            _profileHeader(e),
            const SizedBox(height: 20),
            _accountInfoCard(e),
            const SizedBox(height: 14),
            _securityCard(),
            const SizedBox(height: 28),
            _signOutButton(),
          ],
        ),
      ),
    );
  }

  // ── Profile header ────────────────────────────────────────────────────────

  Widget _profileHeader(Employee e) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
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
              Container(
                width: 116,
                height: 116,
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
              Container(
                width: 104,
                height: 104,
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
                  radius: 46,
                  backgroundColor: _kHigh,
                  backgroundImage: _decodedEmployeeImg != null
                      ? MemoryImage(_decodedEmployeeImg!)
                      : null,
                  child: _decodedEmployeeImg == null
                      ? Icon(Icons.person_rounded, size: 48, color: _kMuted)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Text(
            e.employeeName,
            style: const TextStyle(
              color: _kText,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Company logo + name row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_decodedCompanyLogo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(_decodedCompanyLogo!,
                      width: 18, height: 18, fit: BoxFit.cover),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                e.companyName,
                style: const TextStyle(color: _kSub, fontSize: 13),
              ),
            ],
          ),

          if (e.roles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                e.roles.first,
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

  // ── Account info card ─────────────────────────────────────────────────────

  Widget _accountInfoCard(Employee e) {
    return _card(
      header: 'ACCOUNT INFORMATION',
      headerIcon: Icons.info_outline_rounded,
      children: [
        _infoRow(Icons.badge_outlined, 'Employee ID', e.employeeId),
        _infoRow(Icons.login_rounded, 'Login Code', e.employeeId),
        _infoRow(Icons.business_rounded, 'Company', e.companyName),
        _infoRow(Icons.qr_code_rounded, 'Company Code', e.companyCode),
        if (e.prCode != null && e.prCode!.isNotEmpty)
          _infoRow(Icons.tag_rounded, 'PR Code', e.prCode!),
        if (e.employeeDomain != null && e.employeeDomain!.isNotEmpty)
          _infoRow(Icons.work_outline_rounded, 'Domain', e.employeeDomain!),
        if (e.permissions.isNotEmpty)
          _infoRow(Icons.shield_outlined, 'Permissions',
              e.permissions.join(', ')),
      ],
    );
  }

  // ── Security card ─────────────────────────────────────────────────────────

  Widget _securityCard() {
    return _card(
      header: 'SECURITY',
      headerIcon: Icons.security_rounded,
      children: [
        _actionRow(
          icon: Icons.lock_reset_rounded,
          label: 'Change Password',
          subtitle: 'Update your account password',
          onTap: _openChangePassword,
        ),
      ],
    );
  }

  // ── Card wrapper ──────────────────────────────────────────────────────────

  Widget _card({
    required String header,
    required IconData headerIcon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(headerIcon, color: _kAccent, size: 14),
                ),
                const SizedBox(width: 10),
                Text(
                  header,
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 17, color: _kMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(color: _kMuted, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(
                            color: _kText,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, indent: 16, endIndent: 16, color: _kBorder),
      ],
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _kHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Icon(icon, size: 18, color: _kSub),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: _kText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: _kMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Color(0xFF4A5568)),
          ],
        ),
      ),
    );
  }

  // ── Sign Out button ───────────────────────────────────────────────────────

  Widget _signOutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: _kAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: _kAccent, size: 18),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                color: _kAccent,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Change Password bottom sheet ───────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  final Employee employee;
  const _ChangePasswordSheet({required this.employee});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  static const _kHigh   = Color(0xFF152035);
  static const _kBorder = Color(0xFF1E2D42);
  static const _kAccent = Color(0xFF2563EB);
  static const _kText   = Color(0xFFF0F4FF);
  static const _kMuted  = Color(0xFF4A5568);

  final _formKey      = GlobalKey<FormState>();
  final _oldCtrl      = TextEditingController();
  final _newCtrl      = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscureOld     = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _loading        = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await EmployeeService.changePassword(
        companyCode: widget.employee.companyCode,
        employeeId: widget.employee.employeeId,
        oldPassword: _oldCtrl.text,
        newPassword: _newCtrl.text,
        accessToken: widget.employee.accessToken,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Password changed successfully!',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1625),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomPad),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2D42),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: _kAccent, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Change Password',
                        style: TextStyle(
                          color: _kText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        )),
                    Text('Update your account password',
                        style: TextStyle(color: _kMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Old Password
            _passwordField(
              controller: _oldCtrl,
              label: 'Current Password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscureOld,
              onToggle: () => setState(() => _obscureOld = !_obscureOld),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your current password' : null,
            ),
            const SizedBox(height: 14),

            // New Password
            _passwordField(
              controller: _newCtrl,
              label: 'New Password',
              icon: Icons.lock_open_rounded,
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a new password';
                if (v.length < 4) return 'Minimum 4 characters required';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Confirm Password
            _passwordField(
              controller: _confirmCtrl,
              label: 'Confirm New Password',
              icon: Icons.check_circle_outline_rounded,
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm your password';
                if (v != _newCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 28),

            // Submit button
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: _loading
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _loading ? _kHigh : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _loading
                    ? []
                    : [
                        BoxShadow(
                          color: _kAccent.withValues(alpha: 0.38),
                          blurRadius: 20,
                          offset: const Offset(0, 7),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loading ? null : _submit,
                  borderRadius: BorderRadius.circular(16),
                  splashColor: Colors.white.withValues(alpha: 0.1),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Update Password',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
          color: _kText, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kMuted, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: _kAccent, fontSize: 13),
        prefixIcon: Icon(icon, color: _kMuted, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _kMuted,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: _kHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
      ),
      validator: validator,
    );
  }
}

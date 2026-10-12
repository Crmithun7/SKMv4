import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../models/employee.dart';
import '../utils/error_utils.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _kBg       = Color(0xFF080C15);
  static const _kSurface  = Color(0xFF0F1625);
  static const _kAccent   = Color(0xFF2563EB);
  static const _kBorder   = Color(0xFF1E2D42);
  static const _kText     = Color(0xFFF0F4FF);
  static const _kSub      = Color(0xFF8B9BB4);
  static const _kMuted    = Color(0xFF4A5568);

  final _formKey        = GlobalKey<FormState>();
  final _loginCodeCtrl  = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading       = false;

  @override
  void dispose() {
    _loginCodeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final Employee employee = await AuthService.login(
        _loginCodeCtrl.text.trim(),
        _passwordCtrl.text,
      );
      await StorageService.saveEmployee(employee);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(employee: employee)),
      );
    } catch (e) {
      if (!mounted) return;
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Background glow orbs
          Positioned(
            top: -140,
            right: -110,
            child: _glowOrb(340, _kAccent, 0.11),
          ),
          Positioned(
            bottom: -160,
            left: -110,
            child: _glowOrb(400, const Color(0xFF6C63FF), 0.07),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // ── Logo ───────────────────────────────────────────────
                      Center(
                        child: Container(
                          width: 116,
                          height: 116,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _kSurface,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.07),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _kAccent.withValues(alpha: 0.22),
                                blurRadius: 48,
                                spreadRadius: 0,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/skm.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 44),

                      // ── Heading ────────────────────────────────────────────
                      const Text(
                        'Welcome Back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kText,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sign in to your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kSub,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 52),

                      // ── Login Code ─────────────────────────────────────────
                      _inputField(
                        controller: _loginCodeCtrl,
                        label: 'Login Code',
                        icon: Icons.badge_outlined,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Enter your login code' : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Password ───────────────────────────────────────────
                      _inputField(
                        controller: _passwordCtrl,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _kMuted,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Enter your password' : null,
                      ),

                      const SizedBox(height: 44),

                      // ── Sign In Button ─────────────────────────────────────
                      _primaryButton(
                        label: 'Sign In',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _login,
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _glowOrb(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kMuted, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: _kAccent, fontSize: 13),
        prefixIcon: Icon(icon, color: _kMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _kSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
      ),
      validator: validator,
    );
  }

  Widget _primaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: onPressed == null ? const Color(0xFF1A2436) : null,
        borderRadius: BorderRadius.circular(18),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: _kAccent.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withValues(alpha: 0.08),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  static const _kAccent = Color(0xFF2563EB);

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isCapturing = false;
  XFile? _capturedFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      _selectedCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex < 0) _selectedCameraIndex = 0;
      await _startController(_selectedCameraIndex);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _startController(int index) async {
    await _controller?.dispose();
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Controller init error: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isInitialized = false);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _startController(_selectedCameraIndex);
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final file = await _controller!.takePicture();
      setState(() {
        _capturedFile = file;
        _isCapturing = false;
      });
    } catch (e) {
      setState(() => _isCapturing = false);
      debugPrint('Capture error: $e');
    }
  }

  void _retake() => setState(() => _capturedFile = null);

  void _usePhoto() => Navigator.pop(context, _capturedFile!.path);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _controller = null;
      if (mounted) setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _startController(_selectedCameraIndex);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _capturedFile != null ? _previewScreen() : _cameraScreen(),
    );
  }

  // ── Live camera view ──────────────────────────────────────────────────────

  Widget _cameraScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        if (_isInitialized && _controller != null)
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2),
          ),

        // Top gradient overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 130,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),

        // Bottom gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 180,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),

        // Top controls
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _controlBtn(Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context)),
                _cameraLabel(),
                if (_cameras.length >= 2)
                  _controlBtn(Icons.flip_camera_ios_rounded, onTap: _flipCamera)
                else
                  const SizedBox(width: 46),
              ],
            ),
          ),
        ),

        // Viewfinder corners
        if (_isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                children: [
                  ..._viewfinderCorners(),
                ],
              ),
            ),
          ),

        // Bottom shutter
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                children: [
                  const Text(
                    'Tap to capture',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _shutterButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cameraLabel() {
    if (_cameras.isEmpty) return const SizedBox.shrink();
    final isFront =
        _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isFront ? Icons.face_rounded : Icons.camera_rear_rounded,
              color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            isFront ? 'Front Camera' : 'Back Camera',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _shutterButton() {
    return GestureDetector(
      onTap: _isCapturing ? null : _capture,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
          ),
          // Inner circle
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _isCapturing
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      color: Colors.black54,
                      strokeWidth: 2.5,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _controlBtn(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  List<Widget> _viewfinderCorners() {
    const size = 26.0;
    const thick = 2.0;
    final c = _kAccent.withValues(alpha: 0.7);
    return [
      Positioned(top: 40, left: 40, child: _corner(c, size, thick, top: true,  left: true)),
      Positioned(top: 40, right: 40, child: _corner(c, size, thick, top: true,  left: false)),
      Positioned(bottom: 40, left: 40, child: _corner(c, size, thick, top: false, left: true)),
      Positioned(bottom: 40, right: 40, child: _corner(c, size, thick, top: false, left: false)),
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

  // ── Photo preview ─────────────────────────────────────────────────────────

  Widget _previewScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(_capturedFile!.path), fit: BoxFit.cover),

        // Bottom controls overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retake,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: const Text('Retake',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _kAccent.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _usePhoto,
                        borderRadius: BorderRadius.circular(14),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Use Photo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Close button at top
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _controlBtn(Icons.close_rounded, onTap: _retake),
          ),
        ),
      ],
    );
  }
}

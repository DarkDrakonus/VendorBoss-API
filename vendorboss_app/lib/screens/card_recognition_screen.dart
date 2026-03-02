import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'card_scan_screen.dart'; // re-exports ScanResult, ScannedCardData

/// Full-screen card recognition screen.
///
/// Two recognition paths:
///   1. AI Vision  — captures a still frame and sends to the backend
///                   for identification via Claude vision API.
///   2. Barcode    — fallback for cards/slabs with scannable barcodes.
///
/// Returns a [ScanResult] to the caller with pre-filled card data
/// if recognition succeeds, or a manual-entry signal if it fails.
class CardRecognitionScreen extends StatefulWidget {
  const CardRecognitionScreen({super.key});

  @override
  State<CardRecognitionScreen> createState() =>
      _CardRecognitionScreenState();
}

class _CardRecognitionScreenState extends State<CardRecognitionScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;
  bool _analyzing = false;
  String? _hint; // guidance text that cycles
  Timer? _hintTimer;
  int _hintIndex = 0;
  bool _torchOn = false;
  _ScanMode _mode = _ScanMode.aiVision;

  static const _hints = [
    'Lay the card flat under good light',
    'Fill the frame with the card face',
    'Works on slabs — it reads the PSA/BGS label',
    'Works on sports cards, TCGs, and vintage',
    'Hold steady for a sharper capture',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _startHintCycle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_camera == null || !_camera!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _camera!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _camera = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _camera!.initialize();
      await _camera!.setFocusMode(FocusMode.auto);
      await _camera!.setExposureMode(ExposureMode.auto);

      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _startHintCycle() {
    _hint = _hints[0];
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _hintIndex = (_hintIndex + 1) % _hints.length;
        _hint = _hints[_hintIndex];
      });
    });
  }

  // ── Capture & Identify ────────────────────────────────────────────────────

  Future<void> _captureAndIdentify() async {
    if (_camera == null || !_camera!.value.isInitialized || _analyzing) return;

    setState(() => _analyzing = true);
    _hintTimer?.cancel();

    try {
      // Ensure good focus before capturing
      await _camera!.setFocusMode(FocusMode.locked);
      await Future.delayed(const Duration(milliseconds: 300));

      final file = await _camera!.takePicture();
      final result = await _callIdentifyApi(File(file.path));

      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      await _camera?.setFocusMode(FocusMode.auto);
      _startHintCycle();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Capture failed: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Sends the captured image to the backend which runs it through
  /// the Claude vision API (or Scryfall/Pokemon TCG for confirmed matches).
  ///
  /// Endpoint: POST /api/v1/cards/identify
  /// Body: multipart/form-data with image field
  /// Response: { card_name, game, set_name, card_number, condition,
  ///             image_url, market_price, finish, is_graded,
  ///             grading_company, grade, confidence }
  Future<ScanResult> _callIdentifyApi(File imageFile) async {
    // ── MOCK – replace with real HTTP call when backend is ready ──────────
    // Real implementation:
    //
    // final request = http.MultipartRequest(
    //   'POST',
    //   Uri.parse('${AppConfig.apiBaseUrl}/api/v1/cards/identify'),
    // );
    // request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    // final response = await request.send();
    // final body = await response.stream.bytesToString();
    // final json = jsonDecode(body);
    // return ScanResult(cardData: ScannedCardData.fromJson(json));

    await Future.delayed(const Duration(seconds: 2)); // simulate network

    // Return a realistic mock result so the UI flow works end-to-end
    return ScanResult(
      rawBarcode: null,
      cardData: ScannedCardData(
        cardName:    'Charizard',
        game:        'Pokemon',
        setName:     'Base Set',
        cardNumber:  '4/102',
        imageUrl:    'https://images.pokemontcg.io/base1/4.png',
        marketPrice: 320.00,
        finish:      'holo',
        condition:   'LP',    // AI also estimates condition from image
        confidence:  0.97,
      ),
    );
    // ─────────────────────────────────────────────────────────────────────
  }

  void _toggleTorch() async {
    if (_camera == null) return;
    await _camera!.setFlashMode(_torchOn ? FlashMode.off : FlashMode.torch);
    setState(() => _torchOn = !_torchOn);
  }

  void _switchMode(_ScanMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    if (mode == _ScanMode.barcode) {
      // Hand off to the barcode scanner
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CardScanScreen()),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera preview ────────────────────────────────────────────
          if (_cameraReady && _camera != null)
            Positioned.fill(
              child: CameraPreview(_camera!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),

          // ── Card frame overlay ────────────────────────────────────────
          if (!_analyzing)
            Positioned.fill(
              child: CustomPaint(painter: _CardFramePainter()),
            ),

          // ── Analyzing overlay ─────────────────────────────────────────
          if (_analyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.65),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        color:       AppColors.accent,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Identifying card...',
                      style: TextStyle(
                        color:      Colors.white,
                        fontSize:   18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI is reading the card face',
                      style: TextStyle(
                        color:    Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Top bar ───────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Back
                  _CircleButton(
                    icon:    Icons.close,
                    onTap:   () => Navigator.pop(context,
                        ScanResult.manualEntry()),
                    tooltip: 'Cancel',
                  ),
                  const Spacer(),
                  // Mode toggle
                  _ModeToggle(
                    current:  _mode,
                    onChange: _switchMode,
                  ),
                  const Spacer(),
                  // Torch
                  _CircleButton(
                    icon:    _torchOn
                        ? Icons.flash_on
                        : Icons.flash_off_outlined,
                    onTap:   _toggleTorch,
                    tooltip: 'Toggle torch',
                    active:  _torchOn,
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom panel ──────────────────────────────────────────────
          if (!_analyzing)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.bottomCenter,
                    end:    Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cycling hint
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _hint ?? '',
                        key:          ValueKey(_hint),
                        textAlign:    TextAlign.center,
                        style: TextStyle(
                          color:    Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Shutter button
                    GestureDetector(
                      onTap: _captureAndIdentify,
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                          boxShadow: [
                            BoxShadow(
                              color:      AppColors.accent.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.black,
                          size: 32,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Manual entry escape
                    TextButton(
                      onPressed: () => Navigator.pop(
                          context, ScanResult.manualEntry()),
                      child: const Text(
                        'Enter Manually Instead',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Scan mode enum ────────────────────────────────────────────────────────────

enum _ScanMode { aiVision, barcode }

// ── Mode toggle ───────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final _ScanMode current;
  final ValueChanged<_ScanMode> onChange;

  const _ModeToggle({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color:        Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tab(
            label:    'Identify Card',
            icon:     Icons.auto_awesome,
            selected: current == _ScanMode.aiVision,
            onTap:    () => onChange(_ScanMode.aiVision),
          ),
          _Tab(
            label:    'Barcode',
            icon:     Icons.qr_code,
            selected: current == _ScanMode.barcode,
            onTap:    () => onChange(_ScanMode.barcode),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        selected
              ? AppColors.accent.withOpacity(0.9)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size:  14,
                color: selected ? Colors.black : Colors.white54),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color:      selected ? Colors.black : Colors.white54,
                fontSize:   12,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Circle icon button ────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AppColors.accent.withOpacity(0.3)
                : Colors.black.withOpacity(0.5),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon,
              color: active ? AppColors.accent : Colors.white,
              size:  20),
        ),
      ),
    );
  }
}

// ── Card frame painter ────────────────────────────────────────────────────────
// Draws a darkened vignette with a clear card-shaped window in the centre,
// plus teal corner brackets as an aiming guide.

class _CardFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Card aspect ratio is 63mm × 88mm ≈ 0.716
    const ratio  = 63.0 / 88.0;
    final height = size.height * 0.62;
    final width  = height * ratio;
    final left   = (size.width - width) / 2;
    final top    = (size.height - height) / 2 - size.height * 0.05;
    final rect   = Rect.fromLTWH(left, top, width, height);
    final rrect  = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Darkened overlay with card-shaped hole
    final maskPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final fullRect  = Rect.fromLTWH(0, 0, size.width, size.height);
    final path      = Path()
      ..addRect(fullRect)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, maskPaint);

    // Teal corner brackets
    const len       = 24.0;
    const thick     = 3.0;
    const cRadius   = 6.0;
    final bracketPaint = Paint()
      ..color       = AppColors.accent
      ..strokeWidth = thick
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    void drawCorner(Offset corner, double dx, double dy) {
      canvas.drawLine(corner, corner + Offset(dx * len, 0), bracketPaint);
      canvas.drawLine(corner, corner + Offset(0, dy * len), bracketPaint);
    }

    drawCorner(Offset(left + cRadius, top + cRadius), 1, 1);
    drawCorner(Offset(left + width - cRadius, top + cRadius), -1, 1);
    drawCorner(Offset(left + cRadius, top + height - cRadius), 1, -1);
    drawCorner(Offset(left + width - cRadius, top + height - cRadius), -1, -1);

    // Subtle card outline
    canvas.drawRRect(
      rrect,
      Paint()
        ..color       = AppColors.accent.withOpacity(0.25)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

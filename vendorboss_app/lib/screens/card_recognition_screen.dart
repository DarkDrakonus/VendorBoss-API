import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
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

  Future<ScanResult> _callIdentifyApi(File imageFile) async {
    final response = await ApiService.instance.scanCard(imageFile);

    final scanId  = response['scan_id'] as String?;
    final matches = (response['matches'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (matches.isEmpty) {
      return ScanResult.manualEntry();
    }

    if (!mounted) return ScanResult.manualEntry();
    final confirmed = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _MatchSelectionScreen(
          scanId:    scanId ?? '',
          matches:   matches,
          extracted: (response['extracted'] as Map<String, dynamic>? ?? {}),
        ),
      ),
    );

    if (confirmed == null) return ScanResult.manualEntry();

    return ScanResult(
      rawBarcode: null,
      cardData: ScannedCardData(
        cardName:   confirmed['card_name'] ?? confirmed['player_name'] ?? 'Unknown',
        game:       confirmed['game'] ?? '',
        setName:    confirmed['set_name'] ?? '',
        cardNumber: confirmed['card_number'] ?? '',
        imageUrl:   confirmed['image_url'],
        confidence: (confirmed['confidence'] as num?)?.toDouble(),
        scanId:     scanId,
        productId:  confirmed['product_id'],
      ),
    );
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

// ── Match Selection Screen ────────────────────────────────────────────────────

class _MatchSelectionScreen extends StatelessWidget {
  final String scanId;
  final List<Map<String, dynamic>> matches;
  final Map<String, dynamic> extracted;

  const _MatchSelectionScreen({
    required this.scanId,
    required this.matches,
    required this.extracted,
  });

  @override
  Widget build(BuildContext context) {
    final detectedName = extracted['card_name'] ?? extracted['player_name'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Confirm Card'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surfaceDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI IDENTIFIED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(detectedName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (extracted['card_number'] != null)
                  Text('#\${extracted[\'card_number\']}  \${extracted[\'set_name\'] ?? \'\'}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              matches.length == 1 ? 'Is this the right card?' : 'Select the correct card:',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: matches.length,
              itemBuilder: (context, i) {
                final m = matches[i];
                final confidence = ((m['confidence'] as num?)?.toDouble() ?? 0.0);
                final pct = (confidence * 100).toStringAsFixed(0);
                final reasons = (m['match_reasons'] as List<dynamic>?)?.cast<String>() ?? [];
                final imageUrl = m['image_url'] as String?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, m),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: imageUrl != null
                                ? Image.network(imageUrl, width: 56, height: 78, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _placeholder())
                                : _placeholder(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        m['card_name'] ?? m['player_name'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: confidence >= 0.8 ? AppColors.success.withOpacity(0.15) : AppColors.warning.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text('$pct%',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                              color: confidence >= 0.8 ? AppColors.success : AppColors.warning)),
                                    ),
                                  ],
                                ),
                                if (m['card_number'] != null)
                                  Text('#\${m[\'card_number\']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                if (m['set_name'] != null)
                                  Text(m['set_name'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                if (m['latest_price'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text('\$\${(m[\'latest_price\'] as num).toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
                                ],
                                if (reasons.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4, runSpacing: 4,
                                    children: reasons.map((r) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(4)),
                                      child: Text(r, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                    )).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textLight),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, null),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.textLight),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('None of these — Enter Manually'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 56, height: 78,
    decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(6)),
    child: const Icon(Icons.style, color: AppColors.textLight, size: 28),
  );
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

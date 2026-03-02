import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

/// Full-screen barcode scanner used during card add flow.
/// Returns a [ScanResult] with whatever data we pulled from the barcode
/// and optionally pre-fetched card data from an external API.
class CardScanScreen extends StatefulWidget {
  const CardScanScreen({super.key});

  @override
  State<CardScanScreen> createState() => _CardScanScreenState();
}

class _CardScanScreenState extends State<CardScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _hasScanned = false;
  bool _isLooking = false;
  bool _torchOn = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned || _isLooking) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final raw = barcode.rawValue!;
    setState(() {
      _hasScanned = true;
      _isLooking = true;
      _errorMessage = null;
    });

    await _controller.stop();

    // Try to resolve the barcode to a card
    final result = await _resolveBarcode(raw);

    if (!mounted) return;

    if (result != null) {
      Navigator.pop(context, result);
    } else {
      // Nothing found — let vendor type it manually, pre-filling barcode
      setState(() {
        _isLooking = false;
        _errorMessage =
            'No card found for this barcode. You can add it manually.';
      });
      Navigator.pop(
        context,
        ScanResult(rawBarcode: raw, cardData: null),
      );
    }
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  Future<ScanResult?> _resolveBarcode(String raw) async {
    // In the real implementation this hits the API:
    //   POST /api/v1/cards/lookup?barcode=<raw>
    // which tries Scryfall, Pokemon TCG API, TCDB, etc.
    // For now we return a mock result for any scan so the UI works.

    await Future.delayed(const Duration(milliseconds: 800));

    // Detect if it looks like a Pokemon or MTG collector number
    // format: "swsh4-43" or "base1-4" style (set-number)
    // Real implementation would parse and route to the right API.
    return ScanResult(
      rawBarcode: raw,
      cardData: null, // API response will populate this
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Card'),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off_outlined,
            ),
            onPressed: _toggleTorch,
            tooltip: 'Toggle torch',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Scan overlay — darkened edges with a clear window
          _ScanOverlay(),

          // Instructions + status
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLooking) ...[
                    const CircularProgressIndicator(color: AppColors.accent),
                    const SizedBox(height: 12),
                    const Text(
                      'Looking up card...',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ] else if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.warning, fontSize: 14),
                    ),
                  ] else ...[
                    const Text(
                      'Point at the barcode or QR code on your card',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Works with UPC barcodes and set/number codes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Manual entry fallback
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                    ),
                    onPressed: () =>
                        Navigator.pop(context, ScanResult.manualEntry()),
                    child: const Text('Enter Manually Instead'),
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

// ── Scan overlay with clear centre window ─────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const windowSize = 260.0;
    final top = (size.height - windowSize) / 2 - 60;
    final left = (size.width - windowSize) / 2;

    return Stack(
      children: [
        // Dark mask — top
        Positioned(
          top: 0, left: 0, right: 0,
          height: top,
          child: Container(color: Colors.black54),
        ),
        // Dark mask — bottom
        Positioned(
          top: top + windowSize, left: 0, right: 0, bottom: 0,
          child: Container(color: Colors.black54),
        ),
        // Dark mask — left
        Positioned(
          top: top, left: 0,
          width: left, height: windowSize,
          child: Container(color: Colors.black54),
        ),
        // Dark mask — right
        Positioned(
          top: top, left: left + windowSize,
          right: 0, height: windowSize,
          child: Container(color: Colors.black54),
        ),
        // Corner brackets
        Positioned(
          top: top, left: left,
          width: windowSize, height: windowSize,
          child: CustomPaint(painter: _CornerPainter()),
        ),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 28.0;
    const thickness = 3.0;
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(0, len), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(len, 0), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - len, 0),
        Offset(size.width, 0), paint);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, len), paint);
    // Bottom-left
    canvas.drawLine(
        Offset(0, size.height - len), Offset(0, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(len, size.height), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height - len),
        Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - len, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Result model ──────────────────────────────────────────────────────────────

class ScanResult {
  final String? rawBarcode;
  final ScannedCardData? cardData;
  final bool isManualEntry;

  const ScanResult({
    this.rawBarcode,
    this.cardData,
    this.isManualEntry = false,
  });

  factory ScanResult.manualEntry() =>
      const ScanResult(isManualEntry: true);

  bool get hasCardData => cardData != null;
}

/// Pre-populated card data returned from AI card recognition or barcode lookup.
/// Maps directly onto InventoryItem fields.
class ScannedCardData {
  final String cardName;
  final String game;
  final String setName;
  final String cardNumber;
  final String? imageUrl;
  final double? marketPrice;
  final String? finish;
  final String? condition;   // AI estimates condition from image surface
  final bool?   isGraded;
  final String? gradingCompany;
  final String? grade;
  final double? confidence;  // 0.0 – 1.0, how certain the AI is

  const ScannedCardData({
    required this.cardName,
    required this.game,
    required this.setName,
    required this.cardNumber,
    this.imageUrl,
    this.marketPrice,
    this.finish,
    this.condition,
    this.isGraded,
    this.gradingCompany,
    this.grade,
    this.confidence,
  });

  factory ScannedCardData.fromJson(Map<String, dynamic> json) =>
      ScannedCardData(
        cardName:      json['card_name'] ?? '',
        game:          json['game'] ?? '',
        setName:       json['set_name'] ?? '',
        cardNumber:    json['card_number'] ?? '',
        imageUrl:      json['image_url'],
        marketPrice:   (json['market_price'] as num?)?.toDouble(),
        finish:        json['finish'],
        condition:     json['condition'],
        isGraded:      json['is_graded'],
        gradingCompany: json['grading_company'],
        grade:         json['grade'],
        confidence:    (json['confidence'] as num?)?.toDouble(),
      );
}

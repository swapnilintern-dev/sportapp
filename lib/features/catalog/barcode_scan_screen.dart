import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';

//==============================================================================
// SPOCART — Barcode scan
//------------------------------------------------------------------------------
// Points the camera at the code printed on a carton and returns it. Resolving
// the code to a product is the server's job, so this screen never guesses:
// it reads a code, hands it back, and says plainly when the camera cannot be
// used. Only the symbologies actually printed on sports packaging are read, so
// a random QR poster is not mistaken for a product.
//==============================================================================

/// Formats found on sports cartons and the seller's own labels.
const List<BarcodeFormat> kProductBarcodeFormats = <BarcodeFormat>[
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
  BarcodeFormat.code128,
  BarcodeFormat.code39,
  BarcodeFormat.itf14,
  BarcodeFormat.qrCode,
];

/// Opens the scanner and returns the scanned code, or null if the buyer backed
/// out or the camera is unavailable.
Future<String?> scanProductBarcode(BuildContext context) {
  if (kIsWeb) {
    showAppSnackBar(
      context,
      'Scanning works in the SPOCART app on your phone.',
      tone: SnackTone.neutral,
    );
    return Future<String?>.value();
  }
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (_) => const BarcodeScanScreen(),
    ),
  );
}

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: kProductBarcodeFormats,
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: true,
  );

  /// The scanner fires the same code many times a second; this makes sure only
  /// the first one ever pops the screen.
  bool _handled = false;
  bool _torch = false;
  String? _failure;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final Barcode barcode in capture.barcodes) {
      final String code = (barcode.rawValue ?? '').trim();
      // Anything shorter than this is not a product code; keep looking rather
      // than returning a fragment.
      if (code.length < 4) continue;
      _handled = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {
      // Plenty of phones have no torch; there is nothing to report.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: SpocartAppBar(
        title: 'Scan a barcode',
        actions: <Widget>[
          AppIconButton(
            icon: _torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            tooltip: _torch ? 'Torch off' : 'Torch on',
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (BuildContext context, MobileScannerException error) {
              final String message = switch (error.errorCode) {
                MobileScannerErrorCode.permissionDenied =>
                  'SPOCART needs the camera to scan a barcode. Allow it in your '
                      'phone settings, then try again.',
                MobileScannerErrorCode.unsupported =>
                  'This device cannot scan barcodes. Please search by name instead.',
                _ => 'The camera could not be started. Please search by name instead.',
              };
              // Remember it so the hint below the frame matches what happened.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _failure != message) {
                  setState(() => _failure = message);
                }
              });
              return _CameraProblem(message: message);
            },
          ),
          if (_failure == null) const _ScanFrame(),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.xl,
            child: Text(
              _failure ??
                  'Hold the code inside the frame. SPOCART opens the product it '
                      'belongs to.',
              textAlign: TextAlign.center,
              style: AppTypography.small.copyWith(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// The cut-out the buyer aims with.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 250,
          height: 170,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.white, width: 2),
            borderRadius: AppRadius.mdAll,
          ),
        ),
      ),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.no_photography_outlined,
                  size: 56, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: AppSpacing.lg),
              GhostButton(
                label: 'Search by name instead',
                color: AppColors.white,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

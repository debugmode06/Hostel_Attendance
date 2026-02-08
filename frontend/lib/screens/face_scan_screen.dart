import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';

enum ScanResult { success, notMatched, lowConfidence, duplicate, error }

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _initialized = false;
  bool _scanning = false;
  ScanResult? _lastResult;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) setState(() => _initialized = false);
        return;
      }
      final front = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      _controller = CameraController(
        front,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) {
        setState(() => _initialized = false);
        _showError('Camera Error', e.toString());
      }
    }
  }

  void _showError(String title, String message, {VoidCallback? onDismiss}) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(ctx);
              if (onDismiss != null) onDismiss();
            },
          ),
        ],
      ),
    );
  }

  void _showResultDialog(
    String title,
    String message, {
    VoidCallback? onDismiss,
  }) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(ctx);
              if (onDismiss != null) onDismiss();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndScan() async {
    if (_controller == null || !_initialized || _scanning) return;
    setState(() {
      _scanning = true;
      _lastResult = null;
    });

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);

      final res = await ApiService().scanAttendance(base64);
      final matched = res['matched'] as bool? ?? false;
      final confidence = (res['confidence'] as num?)?.toDouble() ?? 0;

      // Debug logs: number of embeddings compared (if returned)
      final compared = res['compared'] as int? ?? 0;
      debugPrint(
        '[SCAN] Compared embeddings: $compared | confidence: $confidence | threshold: 0.55',
      );

      if (matched) {
        final name = res['studentName'] ?? res['student']?['name'] ?? 'Unknown';
        if (mounted) {
          setState(() {
            _lastResult = ScanResult.success;
            _scanning = false;
          });
          // Haptic success
          try {
            HapticFeedback.mediumImpact();
          } catch (_) {}

          // Show success message
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            _showResultDialog('Success', 'Present: $name');
          }

          // Auto-close camera after success (only on match)
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          // Determine 'almost matched' special case
          final almost = confidence >= 0.45 && confidence <= 0.54;
          setState(() {
            _lastResult = almost
                ? ScanResult.lowConfidence
                : ScanResult.notMatched;
            _scanning = false;
          });
          try {
            HapticFeedback.lightImpact();
          } catch (_) {}

          // Show error using Cupertino dialog and resume scanning when dismissed
          final msg = almost
              ? 'Almost matched, try again'
              : 'Please adjust lighting and try again';
          _showResultDialog(
            'Face Not Recognised',
            msg,
            onDismiss: () {
              // resume scanning after user dismisses
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _captureAndScan();
              });
            },
          );
        }
      }
    } catch (e) {
      final errorStr = e.toString();

      if (mounted) {
        setState(() {
          _lastResult = ScanResult.error;
          _scanning = false;
        });
        _hapticFeedback(false);

        String msg = 'Scan error. Please try again.';
        if (errorStr.contains('409')) {
          msg = 'Already marked for today.';
        } else if (errorStr.contains('404')) {
          msg = 'Student not found or face not registered.';
        } else if (errorStr.contains('503')) {
          msg = 'Face service waking up. Please try again in 30 seconds.';
        } else if (errorStr.contains('408')) {
          msg = 'Face API timeout. Please try again.';
        }

        _showError('Attendance Error', msg);
      }
    }
  }

  Future<void> _hapticFeedback(bool success) async {
    try {
      if (success) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.3),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.white),
        ),
        middle: const Text(
          'Mark Attendance',
          style: TextStyle(color: CupertinoColors.white),
        ),
      ),
      child: !_initialized
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CupertinoActivityIndicator(radius: 20),
                  const SizedBox(height: 16),
                  const Text(
                    'Initializing camera...',
                    style: TextStyle(color: CupertinoColors.white),
                  ),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview
                ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize!.height,
                        height: _controller!.value.previewSize!.width,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                ),
                // Face scanner overlay (animated pulse)
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, child) {
                      return Container(
                        width: 220 * _pulseAnimation.value,
                        height: 280 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _getScannerColor(),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _getScannerColor().withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Scan button
                Positioned(
                  bottom: 48,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _scanning ? null : _captureAndScan,
                      child: AnimatedScale(
                        scale: _scanning ? 0.9 : 1.0,
                        duration: const Duration(milliseconds: 100),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.9),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: _scanning
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CupertinoActivityIndicator(
                                    color: CupertinoColors.white,
                                    radius: 16,
                                  ),
                                )
                              : const Icon(
                                  CupertinoIcons.camera_fill,
                                  color: CupertinoColors.white,
                                  size: 36,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Color _getScannerColor() {
    switch (_lastResult) {
      case ScanResult.success:
        return AppColors.success;
      case ScanResult.notMatched:
      case ScanResult.error:
      case ScanResult.duplicate:
        return AppColors.error;
      case ScanResult.lowConfidence:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }
}

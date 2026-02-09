import 'dart:convert';
import 'dart:async'; // Add async import
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Needed for Colors/Scaffold in some contexts but we use Cupertino mostly
import 'package:camera/camera.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';

enum ScanResult { success, notMatched, lowConfidence, duplicate, error, warmingUp }

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
  
  // Retry logic state
  int _retryCount = 0;
  Timer? _statusTimer;

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
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) {
        setState(() => _initialized = false);
        _showStatusSheet(
          title: 'Camera Error',
          message: e.toString(),
          isError: true,
        );
      }
    }
  }

  // Replaces dialog with a bottom sheet / overlay status
  void _showStatusSheet({
    required String title,
    required String message,
    bool isError = false,
    bool autoDismiss = false,
    int durationMs = 3000,
  }) {
    // We'll use a custom overlay or just update UI state to show message.
    // For iOS style bottom sheet, showCupertinoModalPopup is good, but standard SnackBar or 
    // a persistent bottom widget is better for "status" that might update.
    // Let's use a persistent overlay widget in the Stack instead of a modal implementation 
    // to avoid blocking the camera view.
    
    // NOTE: In this implementation, we simply rely on the UI updating based on state, 
    // but if we want a pop-up sheet:
    
    showCupertinoModalPopup(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title, style: TextStyle(
          color: isError ? CupertinoColors.systemRed : CupertinoColors.label,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        )),
        message: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          if (isError)
            CupertinoActionSheetAction(
              child: const Text('Try Again'),
              onPressed: () {
                Navigator.pop(ctx);
                _captureAndScan(); // Retry manually
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Dismiss'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _captureAndScan({bool isRetry = false}) async {
    if (_controller == null || !_initialized) return;
    if (_scanning && !isRetry) return; // Don't start if already scanning unless it's an internal retry

    if (!isRetry) {
      // fresh start
      _retryCount = 0;
    }

    setState(() {
      _scanning = true;
      _lastResult = null;
    });

    try {
      // 1. Capture image
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);

      // 2. Call API
      final res = await ApiService().scanAttendance(base64);
      final matched = res['matched'] as bool? ?? false;
      final confidence = (res['confidence'] as num?)?.toDouble() ?? 0;
      
      // Check for backend "waking up" message inside 200 OK response if any
      final message = res['message'] as String?;
      if (message != null && message.toLowerCase().contains("waking up")) {
        throw Exception("Face service waking up (503)");
      }

      final name = res['studentName'] ?? res['student']?['name'] ?? 'Unknown';

      if (matched) {
        _handleSuccess(name);
      } else {
        _handleNoMatch(confidence);
      }
    } catch (e) {
      final errorStr = e.toString();
      debugPrint('[SCAN ERROR] $errorStr');

      // Retry logic for timeouts or 503
      bool shouldRetry = false;
      String userMsg = 'Scan error. Please try again.';

      if (errorStr.contains('503') || errorStr.contains('waking up')) {
        userMsg = 'Server warming up. Please wait 5–10 seconds...';
        shouldRetry = true;
      } else if (errorStr.contains('408') || errorStr.contains('timeout')) {
        userMsg = 'Connection timed out. Retrying...';
        shouldRetry = true;
      } else if (errorStr.contains('409')) {
        userMsg = 'Already marked for today.';
      } else if (errorStr.contains('404')) {
        userMsg = 'Student not found or face not registered.';
      }

      if (mounted) {
        // Update UI to show error/warning
        setState(() {
          _lastResult = shouldRetry && _retryCount < 1 ? ScanResult.warmingUp : ScanResult.error;
        });

         // Show friendly message
         _showStatusSheet(
            title: shouldRetry ? 'Warming Up' : 'Error', 
            message: userMsg, 
            isError: !shouldRetry
         );
        
        if (shouldRetry && _retryCount < 1) {
          _retryCount++;
          // Wait 5 seconds then retry
          await Future.delayed(const Duration(seconds: 5));
          if (mounted) _captureAndScan(isRetry: true);
        } else {
          setState(() => _scanning = false);
          _hapticFeedback(false);
        }
      }
    }
  }

  void _handleSuccess(String name) async {
    if (!mounted) return;
    setState(() {
      _lastResult = ScanResult.success;
      _scanning = false;
    });
    
    _hapticFeedback(true);
    
    // Show success bottom sheet (auto dismiss)
    showCupertinoModalPopup(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Attendance Marked!', style: TextStyle(
          color: CupertinoColors.activeGreen,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        )),
        message: Text('Welcome, $name', style: const TextStyle(fontSize: 18)),
      ),
    );
    
    // Auto-close camera
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
       Navigator.pop(context); // Close sheet
       Navigator.pop(context, true); // Close screen
    }
  }

  void _handleNoMatch(double confidence) {
    if (!mounted) return;
    
    final almost = confidence >= 0.45 && confidence <= 0.54;
    setState(() {
      _lastResult = almost ? ScanResult.lowConfidence : ScanResult.notMatched;
      _scanning = false;
    });
    _hapticFeedback(false);

    final msg = almost
        ? 'Almost matched ($confidence). Try moving closely or better lighting.'
        : 'Face not recognized. Ensure you are registered.';
    
    _showStatusSheet(
      title: 'Not Recognized', 
      message: msg,
      isError: true,
    );
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
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withOpacity(0.3),
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
                   // Loading indicator
                   const CupertinoActivityIndicator(color: CupertinoColors.white, radius: 20),
                   const SizedBox(height: 16),
                   Text(
                    'Initializing camera...',
                    style: TextStyle(color: CupertinoColors.white.withOpacity(0.7)),
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
                
                // Dim overlay for better focus
                 Container(color: CupertinoColors.black.withOpacity(0.2)),

                // Face scanner overlay (animated pulse)
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, child) {
                      return Container(
                        width: 250 * _pulseAnimation.value,
                        height: 300 * _pulseAnimation.value, // More manageable ratio
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: _getScannerColor().withOpacity(0.8),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _getScannerColor().withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: _scanning 
                           ? Center(
                               child: Column(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   const CupertinoActivityIndicator(radius: 20, color: CupertinoColors.white),
                                   if (_retryCount > 0)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 10),
                                        child: Text(
                                          "Warming up...",
                                          style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                 ],
                               )
                           )
                           : null,
                      );
                    },
                  ),
                ),

                // Helper Text
                const Positioned(
                  top: 120,
                  left: 0,
                  right: 0,
                  child: Text(
                    "Position face within the frame",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ),

                // Scan button
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      // Disable button only if scanning and NOT retrying (so user sees it active)
                      // Actually if scanning, we show spinner in frame.
                      onPressed: _scanning ? null : _captureAndScan,
                      child: AnimatedScale(
                        scale: _scanning ? 0.9 : 1.0,
                        duration: const Duration(milliseconds: 100),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _scanning 
                                ? CupertinoColors.systemGrey 
                                : AppColors.primary,
                            border: Border.all(color: CupertinoColors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                             _scanning ? CupertinoIcons.arrow_2_circlepath : CupertinoIcons.camera_fill,
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
      case ScanResult.warmingUp:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }
}

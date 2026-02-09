import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';

enum ScanStatus { idle, scanning, success, noMatch, error, warmingUp }

class FaceScanScreenPremium extends StatefulWidget {
  const FaceScanScreenPremium({super.key});

  @override
  State<FaceScanScreenPremium> createState() => _FaceScanScreenPremiumState();
}

class _FaceScanScreenPremiumState extends State<FaceScanScreenPremium>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;
  ScanStatus _scanStatus = ScanStatus.idle;
  
  // Retry logic
  int _retryCount = 0;
  String? _statusMessage;
  
  late AnimationController _fadeController;
  late AnimationController _loaderController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _frameAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loaderController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _frameAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No Camera', 'Camera not available on this device');
        return;
      }
      final front = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      _controller = CameraController(
        front,
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: false,
      );
      await _controller!.initialize();

      // Small delay for visual polish
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        _fadeController.forward();
        setState(() => _cameraReady = true);
      }
    } catch (e) {
      _showError('Camera Error', e.toString());
    }
  }

  Future<void> _captureAndScan({bool isRetry = false}) async {
    if (_scanStatus == ScanStatus.scanning && !isRetry) return;
    if (!_cameraReady || _controller == null) return;

    if (!isRetry) _retryCount = 0;

    setState(() {
      _scanStatus = ScanStatus.scanning;
      _statusMessage = isRetry ? "Retrying..." : null;
    });

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Use specific timeout for Dio if possible, or rely on global
      final response = await ApiService().post(
        '/attendance/scan',
        data: {
          'imageBase64': base64Image,
        },
      );

      if (!mounted) return;

      if (response['matched'] == true) {
        // Success
        await HapticFeedback.mediumImpact();
        setState(() => _scanStatus = ScanStatus.success);
        
        await _showSuccessDialog(
          response['student']?['name'] ?? 'Face Matched',
          response['student']?['roomNo'] ?? '',
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        // No match
        final confidence = (response['confidence'] as num?)?.toDouble() ?? 0.0;
        final message = response['message'] as String? ?? '';
        
        // Check for "waking up" message in 200 OK response
        if (message.toLowerCase().contains('waking up')) {
           throw Exception('Face service waking up (503)');
        }
        
        _handleNoMatch(confidence, message);
      }
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted && _scanStatus != ScanStatus.success && _scanStatus != ScanStatus.warmingUp) {
        // Return to idle if not success/warming up
        // setState(() => _scanStatus = ScanStatus.idle);
        // We might want to keep the error state visible for a moment
      }
    }
  }

  void _handleNoMatch(double confidence, String serverMessage) {
    if (!mounted) return;
    HapticFeedback.lightImpact();

    final isAlmostMatch = confidence >= 0.45;
    
    // Auto-retry if it's a "blur" issue? No, user needs to stabilize.
    
    setState(() {
      _scanStatus = ScanStatus.noMatch;
      _statusMessage = isAlmostMatch 
         ? "Almost matched (${confidence.toStringAsFixed(2)}). Move closer."
         : (serverMessage.isNotEmpty && serverMessage != "Image too blurred or low contrast" ? serverMessage : "Face not recognized");
    });

    // Reset status after a delay so user can try again
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _scanStatus == ScanStatus.noMatch) {
         setState(() {
           _scanStatus = ScanStatus.idle;
           _statusMessage = null;
         });
      }
    });
  }

  void _handleError(Object error) async {
    final eStr = error.toString();
    debugPrint('[SCAN ERROR] $eStr');

    bool shouldRetry = false;
    String userMsg = 'Scan failed';

    if (eStr.contains('503') || eStr.contains('waking up')) {
      userMsg = 'Server warming up...';
      shouldRetry = true;
    } else if (eStr.contains('408') || eStr.contains('timeout')) {
      userMsg = 'Connection timed out';
      shouldRetry = true;
    } else if (eStr.contains('409')) {
      userMsg = 'Already marked for today';
    }

    if (shouldRetry && _retryCount < 1) {
      if (mounted) {
        setState(() {
          _scanStatus = ScanStatus.warmingUp;
          _statusMessage = "$userMsg (Retrying in 5s)";
        });
      }
      _retryCount++;
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) _captureAndScan(isRetry: true);
    } else {
      if (mounted) {
        setState(() {
           _scanStatus = ScanStatus.error;
           _statusMessage = userMsg;
        });
        await HapticFeedback.heavyImpact();
        
        // Reset after delay
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && _scanStatus == ScanStatus.error) {
            setState(() {
              _scanStatus = ScanStatus.idle;
              _statusMessage = null;
            });
          }
        });
      }
    }
  }

  Future<void> _showSuccessDialog(String name, String room) async {
    return showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Icon(
          CupertinoIcons.check_mark_circled,
          color: CupertinoColors.activeGreen,
          size: 40,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Hello, $name!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (room.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Room: $room',
                style: const TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              DateFormat('HH:mm').format(DateTime.now()),
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Done'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showError(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Dismiss'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _loaderController.dispose();
    _controller?.dispose();
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
          style: TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: !_cameraReady ? _buildCameraInitUi() : _buildCameraLiveUi(),
    );
  }

  Widget _buildCameraInitUi() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.black.withOpacity(0.4),
              CupertinoColors.black.withOpacity(0.6),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _loaderController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CupertinoColors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: CupertinoActivityIndicator(
                      radius: 15,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: Tween<double>(begin: 0.5, end: 0.8).animate(
                  CurvedAnimation(
                    parent: _loaderController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Text(
                  'Positioning camera',
                  style: CupertinoTheme.of(context)
                      .textTheme
                      .navLargeTitleTextStyle
                      .copyWith(
                        fontSize: 16,
                        color: CupertinoColors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraLiveUi() {
    Color frameColor = CupertinoColors.white.withOpacity(0.6);
    if (_scanStatus == ScanStatus.success) frameColor = AppColors.success;
    if (_scanStatus == ScanStatus.error || _scanStatus == ScanStatus.noMatch) frameColor = AppColors.error;
    if (_scanStatus == ScanStatus.warmingUp) frameColor = AppColors.warning;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        FadeTransition(
          opacity: _fadeAnimation,
          child: ClipRect(
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
        ),
        // Dark overlay
        Container(color: CupertinoColors.black.withOpacity(0.2)),
        
        // Face guide frame
        Center(
          child: ScaleTransition(
            scale: _frameAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 250,
                height: 320,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: frameColor,
                    width: _scanStatus == ScanStatus.idle ? 2 : 4,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: frameColor.withOpacity(0.3),
                      blurRadius: 20, 
                      spreadRadius: 2
                    )
                  ]
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Corner guides (only show if idle or scanning)
                    if (_scanStatus == ScanStatus.idle || _scanStatus == ScanStatus.scanning) ...[
                      _buildCorner(top: 12, left: 12),
                      _buildCorner(top: 12, right: 12),
                      _buildCorner(bottom: 12, left: 12),
                      _buildCorner(bottom: 12, right: 12),
                    ],
                    
                    // Status text inside frame
                    if (_statusMessage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Scan Button
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Center(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: (_scanStatus == ScanStatus.scanning || _scanStatus == ScanStatus.warmingUp) 
                  ? null 
                  : () => _captureAndScan(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_scanStatus == ScanStatus.scanning || _scanStatus == ScanStatus.warmingUp)
                      ? CupertinoColors.systemGrey
                      : AppColors.primary.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: (_scanStatus == ScanStatus.scanning || _scanStatus == ScanStatus.warmingUp)
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                          radius: 14,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.camera_fill,
                        color: CupertinoColors.white,
                        size: 32,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorner({double? top, double? bottom, double? left, double? right}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: top != null ? BorderSide(color: AppColors.primary, width: 3) : BorderSide.none,
            bottom: bottom != null ? BorderSide(color: AppColors.primary, width: 3) : BorderSide.none,
            left: left != null ? BorderSide(color: AppColors.primary, width: 3) : BorderSide.none,
            right: right != null ? BorderSide(color: AppColors.primary, width: 3) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

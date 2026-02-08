import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';

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
  bool _scanning = false;
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

  Future<void> _captureAndScan() async {
    if (_scanning || !_cameraReady || _controller == null) return;

    setState(() => _scanning = true);

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await ApiService().post(
        '/attendance/scan',
        data: {
          'imageBase64': base64Image,
        },
      );

      if (!mounted) return;

      if (response['matched'] == true) {
        // Success: auto-close camera
        await HapticFeedback.mediumImpact();
        await _showSuccessDialog(
          response['student']?['name'] ?? 'Face Matched',
          response['student']?['roomNo'] ?? '',
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        // No match
        await HapticFeedback.lightImpact();
        _showNoMatchDialog(response['confidence'] ?? 0);
      }
    } catch (e) {
      _showError('Scan Error', e.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
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

  void _showNoMatchDialog(double confidence) {
    final isAlmostMatch = confidence >= 0.45 && confidence < 0.55;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(isAlmostMatch ? 'Almost Matched' : 'Face Not Recognised'),
        content: Text(
          isAlmostMatch
              ? 'Please adjust lighting and try again.'
              : 'Clear lighting and steady face needed.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Retry'),
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
              // Animated loader - scale animation
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
              // Animated text fade
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview with blur background
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
        // Dark overlay for guide
        Container(color: CupertinoColors.black.withOpacity(0.2)),
        // Face guide frame - animated appearance
        Center(
          child: ScaleTransition(
            scale: _frameAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 220,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: CupertinoColors.white.withOpacity(0.6),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Corner guides
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.primary, width: 3),
                            left: BorderSide(
                              color: AppColors.primary,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.primary, width: 3),
                            right: BorderSide(
                              color: AppColors.primary,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.primary,
                              width: 3,
                            ),
                            left: BorderSide(
                              color: AppColors.primary,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.primary,
                              width: 3,
                            ),
                            right: BorderSide(
                              color: AppColors.primary,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Action button
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Center(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _scanning ? null : _captureAndScan,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: _scanning
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                          radius: 14,
                        ),
                      )
                    : Icon(
                        CupertinoIcons.camera_fill,
                        color: CupertinoColors.white,
                        size: _scanning ? 28 : 32,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';

class FaceRegisterScreenAuto extends StatefulWidget {
  final String regNo;
  final String studentName;
  final VoidCallback onSuccess;

  const FaceRegisterScreenAuto({
    super.key,
    required this.regNo,
    required this.studentName,
    required this.onSuccess,
  });

  @override
  State<FaceRegisterScreenAuto> createState() => _FaceRegisterScreenAutoState();
}

class _FaceRegisterScreenAutoState extends State<FaceRegisterScreenAuto>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;
  bool _registering = false;
  String _lightMessage = '';
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

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
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        _fadeController.forward();
        setState(() => _cameraReady = true);
      }
    } catch (e) {
      _showError('Camera Error', e.toString());
    }
  }

  Future<void> _captureAndRegister() async {
    if (_registering || !_cameraReady || _controller == null) return;

    setState(() => _registering = true);

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await ApiService().post(
        '/face/register',
        data: {
          'regNo': widget.regNo,
          'imageBase64': base64Image,
        },
      );

      if (!mounted) return;

      if (response['success'] == true) {
        // Auto-close camera and show success
        await HapticFeedback.mediumImpact();
        if (mounted) {
          await _showSuccessDialog();
          widget.onSuccess(); // Notify parent
          Navigator.pop(context, true);
        }
      } else {
        setState(() => _registering = false);
        _showError(
          'Registration Failed',
          response['message'] ?? 'Please try again',
        );
      }
    } catch (e) {
      setState(() => _registering = false);

      if (mounted) {
        if (e.toString().contains('503')) {
          _showError(
            'Service Unavailable',
            'Please wait 30 seconds and try again.',
          );
        } else if (e.toString().contains('404')) {
          _showError(
            'Student Not Found',
            'Student record not found. Please check registration number.',
          );
        } else {
          _showError('Error', e.toString());
        }
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    return showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const _CheckmarkAnimation(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Face Registered',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              widget.studentName,
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.regNo,
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey2,
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
    _pulseController.dispose();
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
        middle: Text(
          widget.studentName,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      child: !_cameraReady ? _buildInitUi() : _buildCameraUi(),
    );
  }

  Widget _buildInitUi() {
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
                    parent: _pulseController,
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
              Text(
                'Getting ready',
                style: CupertinoTheme.of(context)
                    .textTheme
                    .navLargeTitleTextStyle
                    .copyWith(
                      fontSize: 16,
                      color: CupertinoColors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraUi() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
          ),
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
        // Overlay
        Container(color: CupertinoColors.black.withOpacity(0.2)),
        // Face guide frame
        Center(
          child: Container(
            width: 220,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primary.withOpacity(0.7),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing guide line (top)
                Positioned(
                  top: 8,
                  left: 24,
                  right: 24,
                  child: Container(
                    height: 1,
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                // Pulsing guide line (bottom)
                Positioned(
                  bottom: 8,
                  left: 24,
                  right: 24,
                  child: Container(
                    height: 1,
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Light indicator
        if (_lightMessage.isNotEmpty)
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _lightMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        // Capture button
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Center(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _registering ? null : _captureAndRegister,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: _registering
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
}

class _CheckmarkAnimation extends StatefulWidget {
  const _CheckmarkAnimation();

  @override
  State<_CheckmarkAnimation> createState() => _CheckmarkAnimationState();
}

class _CheckmarkAnimationState extends State<_CheckmarkAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
      ),
      child: const Icon(
        CupertinoIcons.check_mark_circled,
        color: CupertinoColors.activeGreen,
        size: 40,
      ),
    );
  }
}

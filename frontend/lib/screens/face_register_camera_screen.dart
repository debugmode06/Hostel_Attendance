import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import '../theme/app_colors.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import '../services/app_events.dart';

class FaceRegisterCameraScreen extends StatefulWidget {
  final Student student;

  const FaceRegisterCameraScreen({super.key, required this.student});

  @override
  State<FaceRegisterCameraScreen> createState() =>
      _FaceRegisterCameraScreenState();
}

class _FaceRegisterCameraScreenState extends State<FaceRegisterCameraScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _initialized = false;
  bool _registering = false;
  bool _success = false;
  late AnimationController _pulseController;
  late AnimationController _successController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _initialized = false);
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
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

  void _showError(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndRegister() async {
    if (_controller == null || !_initialized || _registering) return;

    // Validate student ID
    if (widget.student.studentId.isEmpty) {
      _showError('Error', 'Student registration number is empty');
      return;
    }

    setState(() => _registering = true);
    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        final image = await _controller!.takePicture();
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);

        print(
          'DEBUG: Registering face for student: ${widget.student.studentId} (${widget.student.name})',
        );
        print(
          'API: Registering face for regNo=${widget.student.studentId}, imageSize=${base64.length} bytes',
        );

        final response = await ApiService().registerFace(
          widget.student.studentId,
          base64,
        );

        if (response['success'] == true || response.containsKey('_id')) {
          // Success
          _successController.forward();
          setState(() {
            _registering = false;
            _success = true;
          });
          // Notify other screens
          AppEvents.instance.faceRegisterVersion.value++;
          AppEvents.instance.studentsVersion.value++;

          // Auto-close after 1.5 seconds (only on success)
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) Navigator.pop(context, true);
          return; // Success - exit retry loop
        } else {
          // Error response from backend
          if (mounted) {
            final msg = response['message'] ?? 'Failed to register face';
            _showError('Registration Failed', msg);
            setState(() => _registering = false);
          }
          return; // Not a transient error - exit retry loop
        }
      } catch (e) {
        retries++;
        final errorStr = e.toString();
        print('DEBUG: Registration attempt $retries/$maxRetries failed: $e');

        // Check error type
        bool isTransientError =
            errorStr.contains('503') ||
            errorStr.contains('timeout') ||
            errorStr.contains('unavailable');

        if (isTransientError && retries < maxRetries) {
          // Show retry message with proper Cupertino design
          if (mounted) {
            showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: const Text('Service Busy'),
                content: Text('Retrying... (${retries}/$maxRetries)'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('OK'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            );
          }
          // Wait before retrying
          await Future.delayed(const Duration(seconds: 3));
          continue; // Retry
        }

        // Non-transient error or final retry - show error and exit
        if (mounted) {
          String msg = 'Registration failed. Please try again.';

          if (errorStr.contains('DioException(400)')) {
            msg = 'Face could not be detected clearly. Please try again.';
          } else if (errorStr.contains('DioException(408)')) {
            msg = 'Face API timeout. Please try again.';
          } else if (errorStr.contains('DioException(503)')) {
            msg = 'Face service is waking up. Please try again in 30 seconds.';
          } else if (errorStr.contains('statusCode 503')) {
            msg = 'Face service is unavailable. Please try again later.';
          } else if (errorStr.contains('404')) {
            msg = 'Student not found. Please check the registration number.';
          } else if (errorStr.contains('Face')) {
            msg = errorStr.split(': ').skip(1).join(': ');
          }

          _showError('Registration Failed', msg);
          setState(() => _registering = false);
        }
        return; // Exit retry loop
      }
    }

    // All retries exhausted
    if (mounted) {
      _showError(
        'Registration Failed',
        'Face service is unavailable. Please try again later.',
      );
      setState(() => _registering = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _successController.dispose();
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
                // Face frame overlay (animated)
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) {
                      final scale = 0.9 + 0.1 * _pulseController.value;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 240,
                          height: 320,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.7),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Status overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _success
                      ? _buildSuccessOverlay()
                      : _buildInstructionOverlay(),
                ),
                // Capture button
                Positioned(
                  bottom: 48,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _registering || _success
                          ? null
                          : _captureAndRegister,
                      child: AnimatedScale(
                        scale: _registering ? 0.9 : 1.0,
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
                                blurRadius: 20,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: _registering
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
                                  size: 32,
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

  Widget _buildInstructionOverlay() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            CupertinoColors.black.withValues(alpha: 0.8),
            CupertinoColors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Registering: ${widget.student.name}',
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Text(
              'Position your face inside the frame',
              style: TextStyle(
                color: CupertinoColors.inactiveGray,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            CupertinoColors.black.withValues(alpha: 0.8),
            CupertinoColors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(
                parent: _successController,
                curve: Curves.elasticOut,
              ),
            ),
            child: Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 64,
              color: AppColors.success2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Face registered successfully',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

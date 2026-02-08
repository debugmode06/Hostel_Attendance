import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/app_events.dart';

class BulkStudentUploadScreen extends StatefulWidget {
  const BulkStudentUploadScreen({super.key});

  @override
  State<BulkStudentUploadScreen> createState() =>
      _BulkStudentUploadScreenState();
}

class _BulkStudentUploadScreenState extends State<BulkStudentUploadScreen> {
  final _studentsData = <String>[];
  bool _uploading = false;
  String? _error;
  int? _successCount;
  int? _failureCount;
  final _textController = TextEditingController();

  void _addStudentData() {
    if (_textController.text.isEmpty) {
      _showError('Error', 'Please enter student data');
      return;
    }
    setState(() {
      _studentsData.add(_textController.text);
      _textController.clear();
    });
  }

  Future<void> _uploadStudents() async {
    if (_studentsData.isEmpty) {
      _showError('Error', 'No students to upload');
      return;
    }

    setState(() => _uploading = true);
    try {
      // Parse CSV-like format: name,regNo,roomNo,dept,category,college
      final students = <Map<String, dynamic>>[];

      for (final line in _studentsData) {
        final parts = line.split(',');
        if (parts.length >= 6) {
          students.add({
            'name': parts[0].trim(),
            'regNo': parts[1].trim(),
            'roomNo': parts[2].trim(),
            'dept': parts[3].trim(),
            'category': parts[4].trim(),
            'college': parts[5].trim(),
          });
        }
      }

      if (students.isEmpty) {
        setState(() {
          _error =
              'No valid students found. Format: name,regNo,roomNo,dept,category,college';
          _uploading = false;
        });
        return;
      }

      final response = await ApiService().bulkCreateStudents(students);
      final success = response['insertedCount'] ?? response['success'] ?? 0;
      final skipped = response['skippedCount'] ?? response['failed'] ?? 0;

      setState(() {
        _successCount = success;
        _failureCount = skipped;
        _uploading = false;
      });

      AppEvents.instance.studentsVersion.value++;

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Upload Complete'),
            content: Text(
              'Created: $success students\nSkipped (duplicate): $skipped',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Done'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Upload failed: $e';
        _uploading = false;
      });
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
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Bulk Upload')),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.inactiveGray),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Add Students (CSV Format)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Format: name,regNo,roomNo,dept,category,college',
                      style: TextStyle(color: CupertinoColors.inactiveGray),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Example: John Smith,CSE2024001,A101,CSE,UG,MyCollege',
                      style: TextStyle(
                        color: CupertinoColors.inactiveGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Input field
              CupertinoTextField(
                controller: _textController,
                placeholder: 'name,regNo,roomNo,dept,category,college',
                padding: const EdgeInsets.all(12),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),

              // Add button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: AppColors.primary,
                  onPressed: _addStudentData,
                  child: const Text('Add Student'),
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.destructiveRed.withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CupertinoColors.destructiveRed),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: CupertinoColors.destructiveRed,
                      fontSize: 12,
                    ),
                  ),
                ),

              if (_error != null) const SizedBox(height: 16),

              // Students list
              if (_studentsData.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Students to Upload (${_studentsData.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: CupertinoColors.inactiveGray),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: _studentsData.asMap().entries.map((e) {
                          final idx = e.key;
                          final data = e.value;
                          final parts = data.split(',');

                          return Column(
                            children: [
                              if (idx > 0)
                                Divider(
                                  height: 1,
                                  color: CupertinoColors.inactiveGray,
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            parts.isNotEmpty
                                                ? parts[0].trim()
                                                : 'Unknown',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            parts.length > 1
                                                ? parts[1].trim()
                                                : 'No ID',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  CupertinoColors.inactiveGray,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _studentsData.removeAt(idx);
                                        });
                                      },
                                      child: const Icon(
                                        CupertinoIcons.xmark_circle_fill,
                                        color: CupertinoColors.destructiveRed,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Upload button
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        onPressed: _uploading ? null : _uploadStudents,
                        child: _uploading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CupertinoActivityIndicator(
                                  color: CupertinoColors.white,
                                ),
                              )
                            : const Text(
                                'Upload Students',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),

              // Success message
              if (_successCount != null)
                Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload Successful',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.systemGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Created: $_successCount students\nSkipped: $_failureCount (duplicates)',
                            style: const TextStyle(
                              color: CupertinoColors.systemGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

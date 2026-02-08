import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class BulkStudentUploadScreen extends StatefulWidget {
  const BulkStudentUploadScreen({super.key});

  @override
  State<BulkStudentUploadScreen> createState() =>
      _BulkStudentUploadScreenState();
}

// Alias for backward compatibility
typedef BulkStudentUploadScreenComplete = BulkStudentUploadScreen;

class _BulkStudentUploadScreenState extends State<BulkStudentUploadScreen> {
  List<Map<String, dynamic>> _studentsToUpload = [];
  bool _uploading = false;
  int _uploadedCount = 0;
  bool _showingPreview = false;
  final TextEditingController _csvInput = TextEditingController();

  void _parseCSV(String csvText) {
    final lines = csvText.trim().split('\n');
    if (lines.isEmpty) return;

    final headers = lines[0]
        .split(',')
        .map((h) => h.trim().toLowerCase())
        .toList();
    final students = <Map<String, dynamic>>[];
    final errors = <String>[];

    // Validate headers
    final requiredHeaders = [
      'regno',
      'name',
      'roomno',
      'dept',
      'category',
      'college',
    ];
    final missingHeaders = requiredHeaders
        .where((h) => !headers.contains(h))
        .toList();

    if (missingHeaders.isNotEmpty) {
      _showError(
        'Missing Headers',
        'Required: ${missingHeaders.join(", ")}\nActual: ${headers.join(", ")}',
      );
      return;
    }

    // Parse rows
    final regNos = <String>{};
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final values = line.split(',').map((v) => v.trim()).toList();
      if (values.length < requiredHeaders.length) {
        errors.add('Row $i: insufficient columns');
        continue;
      }

      final regNo = values[headers.indexOf('regno')].toUpperCase();
      final name = values[headers.indexOf('name')];
      final roomNo = values[headers.indexOf('roomno')];
      final dept = values[headers.indexOf('dept')];
      final category = values[headers.indexOf('category')];
      final college = values[headers.indexOf('college')];

      // Validation
      if (regNo.isEmpty || name.isEmpty || roomNo.isEmpty) {
        errors.add('Row $i: missing required field');
        continue;
      }

      if (regNos.contains(regNo)) {
        errors.add('Row $i: duplicate regNo ($regNo)');
        continue;
      }

      regNos.add(regNo);
      students.add({
        'regNo': regNo,
        'name': name,
        'roomNo': roomNo,
        'dept': dept,
        'category': category,
        'college': college,
        'status': 'pending',
      });
    }

    setState(() {
      _studentsToUpload = students;
      _showingPreview = true;
    });

    if (errors.isNotEmpty && students.isNotEmpty) {
      _showWarning(
        'Parsing Issues',
        '${errors.length} rows skipped:\n${errors.take(5).join("\n")}${errors.length > 5 ? "\n+${errors.length - 5} more" : ""}',
      );
    }
  }

  Future<void> _uploadStudents() async {
    if (_studentsToUpload.isEmpty) {
      _showError('No Students', 'Please add students to upload');
      return;
    }

    setState(() => _uploading = true);
    _uploadedCount = 0;

    try {
      final payload = _studentsToUpload
          .map(
            (s) => {
              'regNo': s['regNo'],
              'name': s['name'],
              'roomNo': s['roomNo'],
              'dept': s['dept'],
              'category': s['category'],
              'college': s['college'],
            },
          )
          .toList();

      final response = await ApiService().post(
        '/students/bulk',
        data: {
          'students': payload,
        },
      );

      if (mounted) {
        _uploadedCount = response['createdCount'] ?? 0;
        final failed = response['failed'] as List? ?? [];

        if (_uploadedCount > 0) {
          await _showSuccessDialog(_uploadedCount, failed);
          setState(() {
            _studentsToUpload.clear();
            _csvInput.clear();
            _showingPreview = false;
          });
        } else {
          _showError(
            'Upload Failed',
            'No students were created.\n${failed.isNotEmpty ? failed.map((f) => "${f['row']}: ${f['reason']}").join("\n") : ""}',
          );
        }
      }
    } catch (e) {
      _showError('Upload Error', e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showSuccessDialog(int count, List failed) async {
    return showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Upload Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text('$count students added successfully'),
            if (failed.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${failed.length} failed',
                style: const TextStyle(
                  color: CupertinoColors.systemRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
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
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showWarning(String title, String message) {
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
    _csvInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Bulk Student Upload'),
      ),
      child: SafeArea(
        child: _showingPreview ? _buildPreview() : _buildInputForm(),
      ),
    );
  }

  Widget _buildInputForm() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CSV Format:',
                  style: CupertinoTheme.of(
                    context,
                  ).textTheme.navTitleTextStyle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'regNo,name,roomNo,dept,category,college\n'
                    'ECE2024001,John Doe,201,ECE,College,HIT\n'
                    'ECE2024002,Jane Smith,202,ECE,Sports Quota,HIT',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Courier',
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Paste CSV Data:',
                  style: CupertinoTheme.of(
                    context,
                  ).textTheme.navTitleTextStyle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _csvInput,
                  placeholder: 'Paste your CSV data here...',
                  maxLines: 10,
                  minLines: 10,
                  padding: const EdgeInsets.all(12),
                  style: const TextStyle(fontSize: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.separator),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: AppColors.primary,
                    onPressed: _csvInput.text.isEmpty
                        ? null
                        : () => _parseCSV(_csvInput.text),
                    child: const Text('Preview'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Preview (${_studentsToUpload.length} students)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () =>
                                setState(() => _showingPreview = false),
                            child: const Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _PreviewTile(student: _studentsToUpload[i]),
                  childCount: _studentsToUpload.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: CupertinoColors.separator)),
          ),
          child: Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: CupertinoColors.systemGrey3,
                  onPressed: _uploading
                      ? null
                      : () => setState(() => _showingPreview = false),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  color: AppColors.success,
                  onPressed: _uploading ? null : _uploadStudents,
                  child: _uploading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  CupertinoColors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Uploading...'),
                          ],
                        )
                      : const Text('Upload'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final Map<String, dynamic> student;

  const _PreviewTile({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: CupertinoColors.systemGrey4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                student['name'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.systemGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${student['regNo']} • Room ${student['roomNo']}',
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                student['dept'] ?? '',
                style: const TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
              const Text(
                ' • ',
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
              Text(
                student['category'] ?? '',
                style: const TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

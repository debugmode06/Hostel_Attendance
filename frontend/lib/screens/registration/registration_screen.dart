import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../bulk_student_upload_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _roomNoCtrl = TextEditingController();
  List<String> _categories = [];
  List<String> _colleges = [];
  String _category = '';
  String _college = '';
  String _dept = '';
  bool _loading = false;

  final _categoriesDefault = [
    '7.5% Quota',
    'Counselling',
    'Sports Quota',
    'Management',
    'College',
  ];
  final _collegesDefault = ['HIT', 'HICET', 'ARC'];
  final _depts = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'IT', 'OTHER'];

  @override
  void initState() {
    super.initState();
    _categories = _categoriesDefault;
    _colleges = _collegesDefault;
    if (_categories.isNotEmpty) _category = _categories.first;
    if (_colleges.isNotEmpty) _college = _colleges.first;
    if (_depts.isNotEmpty) _dept = _depts.first;
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final cat = await ApiService().getCategories();
      final col = await ApiService().getColleges();
      if (mounted && cat.isNotEmpty) {
        setState(() {
          _categories = cat.map((e) => e.toString()).toList();
          if (_category.isEmpty && _categories.isNotEmpty)
            _category = _categories.first;
        });
      }
      if (mounted && col.isNotEmpty) {
        setState(() {
          _colleges = col.map((e) => e.toString()).toList();
          if (_college.isEmpty && _colleges.isNotEmpty)
            _college = _colleges.first;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _nameCtrl.dispose();
    _roomNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService().createStudent({
        'regNo': _studentIdCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'roomNo': _roomNoCtrl.text.trim(),
        'dept': _dept,
        'category': _category,
        'college': _college,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student registered successfully'),
            backgroundColor: AppTheme.present,
          ),
        );
        _formKey.currentState!.reset();
        _studentIdCtrl.clear();
        _nameCtrl.clear();
        _roomNoCtrl.clear();
        // notify other screens to refresh lists and counts
        AppEvents.instance.studentsVersion.value++;
        AppEvents.instance.faceRegisterVersion.value++;
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('409')
            ? 'Register number already exists'
            : 'Failed to register';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.absent),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openBulkUpload() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Upload CSV'),
        content: SizedBox(
          width: 600,
          height: 300,
          child: Column(
            children: [
              const Text(
                'Paste CSV rows: regNo,name,roomNo,dept,category,college',
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final lines = text
                  .split(RegExp(r"\r?\n"))
                  .map((l) => l.trim())
                  .where((l) => l.isNotEmpty)
                  .toList();
              final rows = <Map<String, dynamic>>[];
              for (final l in lines) {
                final cols = l.split(',');
                if (cols.length < 6) continue;
                rows.add({
                  'regNo': cols[0].trim(),
                  'name': cols[1].trim(),
                  'roomNo': cols[2].trim(),
                  'dept': cols[3].trim(),
                  'category': cols[4].trim(),
                  'college': cols[5].trim(),
                });
              }
              if (rows.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No valid rows found')),
                );
                return;
              }
              try {
                final resp = await ApiService().bulkCreateStudents(rows);
                final failed = resp['failed'] as List<dynamic>? ?? [];
                final createdCount = resp['createdCount'] ?? 0;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Created $createdCount rows, failed ${failed.length}',
                    ),
                  ),
                );
                // notify other screens
                AppEvents.instance.studentsVersion.value++;
                AppEvents.instance.faceRegisterVersion.value++;
                Navigator.pop(ctx, true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bulk upload failed: $e')),
                );
              }
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
    if (result == true) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.doc_on_clipboard),
            tooltip: 'Bulk Upload',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BulkStudentUploadScreen(),
                ),
              ).then((_) {
                // Refresh when bulk upload completes
                AppEvents.instance.studentsVersion.value++;
              });
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF6F7FB),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Student Info',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        CupertinoTextField(
                          controller: _studentIdCtrl,
                          placeholder: 'Register Number (Unique ID)',
                          padding: const EdgeInsets.all(12),
                        ),
                        const SizedBox(height: 12),
                        CupertinoTextField(
                          controller: _nameCtrl,
                          placeholder: 'Student Name',
                          padding: const EdgeInsets.all(12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Academic Info',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _dept.isEmpty ? null : _dept,
                          decoration: const InputDecoration(
                            labelText: 'Department',
                          ),
                          items: _depts
                              .map(
                                (d) =>
                                    DropdownMenuItem(value: d, child: Text(d)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _dept = v ?? _depts.first),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _category.isEmpty ? null : _category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: _categories
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) => setState(
                            () => _category = v ?? _categories.first,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Hostel Info',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        CupertinoTextField(
                          controller: _roomNoCtrl,
                          placeholder: 'Room Number',
                          padding: const EdgeInsets.all(12),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _college.isEmpty ? null : _college,
                          decoration: const InputDecoration(
                            labelText: 'College',
                          ),
                          items: _colleges
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _college = v ?? _colleges.first),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _openBulkUpload,
                    child: const Text('Bulk Upload (.csv paste)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

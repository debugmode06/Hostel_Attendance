import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class StudentStatusHistoryScreen extends StatefulWidget {
  final Student student;

  const StudentStatusHistoryScreen({super.key, required this.student});

  @override
  State<StudentStatusHistoryScreen> createState() =>
      _StudentStatusHistoryScreenState();
}

class _StudentStatusHistoryScreenState extends State<StudentStatusHistoryScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;
  int? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService().getStudentAttendanceHistory(
        widget.student.studentId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      if (mounted) {
        setState(() {
          _records = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance History - ${widget.student.name}'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                    ),
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(DateFormat('MMMM')
                                  .format(DateTime(2024, m))),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _selectedMonth = v);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                    ),
                    items: List.generate(5, (i) => DateTime.now().year - i)
                        .map((y) =>
                            DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _selectedYear = v);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: const TextStyle(color: AppTheme.absent)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _records.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No records for this month',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _records.length,
                            itemBuilder: (_, i) {
                              final r = _records[i];
                              final status = r['status'] ?? 'Absent';
                              final date = r['date']?.toString() ?? '';
                              final time = r['time'] != null
                                  ? DateFormat('h:mm a').format(
                                      DateTime.parse(r['time'].toString()))
                                  : '-';
                              final isPresent = status == 'Present';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isPresent
                                        ? AppTheme.present.withOpacity(0.2)
                                        : AppTheme.absent.withOpacity(0.2),
                                    child: Icon(
                                      isPresent
                                          ? CupertinoIcons.checkmark
                                          : CupertinoIcons.xmark,
                                      color: isPresent
                                          ? AppTheme.present
                                          : AppTheme.absent,
                                    ),
                                  ),
                                  title: Text(
                                    date,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text('$status at $time'),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPresent
                                          ? AppTheme.present.withOpacity(0.2)
                                          : AppTheme.absent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isPresent
                                            ? AppTheme.present
                                            : AppTheme.absent,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

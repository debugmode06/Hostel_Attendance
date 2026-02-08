import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/attendance.dart';
import '../../widgets/empty_state.dart';
import '../../services/api_service.dart';

class ReportDetailScreen extends StatefulWidget {
  final String? date;

  const ReportDetailScreen({super.key, this.date});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  String _targetDate = '';
  List<AttendanceRecord> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _targetDate =
        widget.date ??
        DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now().subtract(const Duration(days: 1)));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().getReport(date: _targetDate);
      final list =
          (res['records'] as List?)
              ?.map(
                (e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          [];
      if (mounted) {
        setState(() {
          _records = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load report';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report - $_targetDate'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.calendar),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(_targetDate) ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _targetDate = DateFormat('yyyy-MM-dd').format(picked);
                });
                _load();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: AppTheme.absent)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _records.isEmpty
          ? const Center(
              child: EmptyState(
                emoji: '📋',
                title: 'No records for this date',
                subtitle: 'Select another date',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length,
              itemBuilder: (_, i) {
                final r = _records[i];
                final isPresent = r.status == 'Present';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPresent
                          ? AppTheme.present.withValues(alpha: 0.2)
                          : AppTheme.absent.withValues(alpha: 0.2),
                      child: Icon(
                        isPresent
                            ? CupertinoIcons.checkmark
                            : CupertinoIcons.xmark,
                        color: isPresent ? AppTheme.present : AppTheme.absent,
                      ),
                    ),
                    title: Text(
                      r.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${r.studentId} • ${r.roomNo ?? '-'} • ${r.time != null ? DateFormat('h:mm a').format(r.time!) : r.status}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPresent
                            ? AppTheme.present.withValues(alpha: 0.2)
                            : AppTheme.absent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        r.status,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isPresent ? AppTheme.present : AppTheme.absent,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

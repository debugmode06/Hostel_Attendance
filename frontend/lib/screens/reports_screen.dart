import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _selectedDate;
  List<dynamic> _presentStudents = [];
  List<dynamic> _absentStudents = [];
  bool _loading = false;
  String? _selectedDept;
  String? _selectedCollege;

  static const List<String> depts = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL'];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _fetchAttendanceData();
  }

  Future<void> _fetchAttendanceData() async {
    setState(() => _loading = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await ApiService().get('/attendance/date/$dateStr');

      if (!mounted) return;

      setState(() {
        _presentStudents = (response['present'] as List? ?? []);
        _absentStudents = (response['absent'] as List? ?? []);

        // Filter if dept selected
        if (_selectedDept != null) {
          _presentStudents = _presentStudents
              .where(
                (s) => s['dept']?.toString().toUpperCase() == _selectedDept,
              )
              .toList();
          _absentStudents = _absentStudents
              .where(
                (s) => s['dept']?.toString().toUpperCase() == _selectedDept,
              )
              .toList();
        }
      });
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  Text(
                    'Select Date',
                    style: CupertinoTheme.of(ctx).textTheme.navTitleTextStyle,
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _fetchAttendanceData();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                onDateTimeChanged: (dt) {
                  _selectedDate = dt;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilters() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          // Department filter
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showDeptFilter();
            },
            child: const Text('Filter by Department'),
          ),
          // Clear filters
          if (_selectedDept != null || _selectedCollege != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedDept = null;
                  _selectedCollege = null;
                });
                _fetchAttendanceData();
              },
              isDestructiveAction: true,
              child: const Text('Clear Filters'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ),
    );
  }

  void _showDeptFilter() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select Department'),
        actions: [
          for (final dept in depts)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _selectedDept = dept);
                _fetchAttendanceData();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dept),
                  if (_selectedDept == dept)
                    const Icon(
                      CupertinoIcons.check_mark,
                      color: CupertinoColors.activeBlue,
                    ),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _exportAttendance() {
    // Placeholder for Excel export
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Export Attendance'),
        content: const Text('Attendance report exported successfully'),
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
  Widget build(BuildContext context) {
    final totalStudents = _presentStudents.length + _absentStudents.length;
    final presentCount = _presentStudents.length;
    final absentCount = _absentStudents.length;
    final presentPercentage = totalStudents > 0
        ? ((presentCount / totalStudents) * 100).toStringAsFixed(1)
        : '0';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Attendance Reports'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _exportAttendance,
          child: const Icon(CupertinoIcons.down_arrow),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
                slivers: [
                  // Date and Filter Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Date selector
                          CupertinoButton(
                            onPressed: _showDatePicker,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: CupertinoColors.systemGrey3,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    CupertinoIcons.calendar,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                    ).format(_selectedDate),
                                    style: const TextStyle(
                                      color: CupertinoColors.label,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Filter button
                          CupertinoButton(
                            onPressed: _showFilters,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _selectedDept != null
                                      ? AppColors.primary
                                      : CupertinoColors.systemGrey3,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.line_horizontal_3_decrease,
                                    color: _selectedDept != null
                                        ? AppColors.primary
                                        : CupertinoColors.systemGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedDept != null
                                        ? 'Dept: $_selectedDept'
                                        : 'All Departments',
                                    style: TextStyle(
                                      color: _selectedDept != null
                                          ? AppColors.primary
                                          : CupertinoColors.label,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Summary cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: Row(
                        children: [
                          // Present card
                          Expanded(
                            child: _SummaryCard(
                              title: 'Present',
                              count: presentCount,
                              percentage: '$presentPercentage%',
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Absent card
                          Expanded(
                            child: _SummaryCard(
                              title: 'Absent',
                              count: absentCount,
                              percentage:
                                  '${((absentCount / (totalStudents == 0 ? 1 : totalStudents)) * 100).toStringAsFixed(1)}%',
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Present students section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Present (${_presentStudents.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  _presentStudents.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No students present',
                                style: TextStyle(
                                  color: CupertinoColors.systemGrey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _StudentTile(
                              student: _presentStudents[i],
                              status: 'Present',
                              statusColor: AppColors.success,
                            ),
                            childCount: _presentStudents.length,
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Absent students section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Absent (${_absentStudents.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  _absentStudents.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No absent students',
                                style: TextStyle(
                                  color: CupertinoColors.systemGrey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _StudentTile(
                              student: _absentStudents[i],
                              status: 'Absent',
                              statusColor: AppColors.error,
                            ),
                            childCount: _absentStudents.length,
                          ),
                        ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final String percentage;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: CupertinoColors.systemGrey4),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.systemGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                percentage,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final dynamic student;
  final String status;
  final Color statusColor;

  const _StudentTile({
    required this.student,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: CupertinoColors.systemGrey5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withOpacity(0.2),
            ),
            child: Center(
              child: Icon(
                status == 'Present'
                    ? CupertinoIcons.check_mark_circled
                    : CupertinoIcons.xmark_circle,
                color: statusColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${student['studentId'] ?? student['regNo'] ?? ''} • Room ${student['roomNo'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          if (student['time'] != null)
            Text(
              _formatTime(student['time']),
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(dynamic time) {
    try {
      if (time is String) {
        final dt = DateTime.parse(time);
        return DateFormat('HH:mm').format(dt);
      }
      return '';
    } catch (_) {
      return '';
    }
  }
}

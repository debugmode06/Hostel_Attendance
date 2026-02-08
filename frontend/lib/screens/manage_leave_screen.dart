import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'student_status_history_screen.dart';

class ManageLeaveScreen extends StatefulWidget {
  const ManageLeaveScreen({super.key});

  @override
  State<ManageLeaveScreen> createState() => _ManageLeaveScreenState();
}

class _ManageLeaveScreenState extends State<ManageLeaveScreen> {
  List<Student> _students = [];
  List<Student> _filtered = [];
  bool _loading = true;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService().getStudents();
      final students =
          list.map((e) => Student.fromJson(Map<String, dynamic>.from(e))).toList();
      if (mounted) {
        setState(() {
          _students = students;
          _applyFilter();
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

  void _applyFilter() {
    if (_search.isEmpty) {
      _filtered = _students;
      return;
    }
    final q = _search.toLowerCase();
    _filtered = _students
        .where((s) =>
            s.studentId.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q) ||
            s.roomNo.toLowerCase().contains(q))
        .toList();
  }

  void _showLeaveOptions(BuildContext context, Student s) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.person),
              title: Text(s.name),
              subtitle: Text('${s.studentId} - ${s.roomNo}'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(CupertinoIcons.house),
              title: const Text('None'),
              subtitle: const Text('Normal attendance'),
              onTap: () => _setLeaveStatus(ctx, s, 'none', null),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.airplane),
              title: const Text('On Leave'),
              subtitle: const Text("Won't auto mark as absent"),
              onTap: () => _setLeaveStatus(ctx, s, 'on_leave', null),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.heart_fill),
              title: const Text('Medical'),
              subtitle: const Text("Won't auto mark as absent"),
              onTap: () => _setLeaveStatus(ctx, s, 'medical', null),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setLeaveStatus(
      BuildContext ctx, Student s, String status, DateTime? until) async {
    Navigator.pop(ctx);
    try {
      await ApiService().updateLeaveStatus(s.studentId, status, until);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave status updated: $status'),
            backgroundColor: AppTheme.present,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: $e'), backgroundColor: AppTheme.absent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Leave / Permission'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by ID, name, room...',
                prefixIcon: Icon(CupertinoIcons.search),
              ),
              onChanged: (v) {
                setState(() {
                  _search = v;
                  _applyFilter();
                });
              },
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
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final s = _filtered[i];
                            final isOnLeave =
                                s.leaveStatus == 'on_leave' || s.leaveStatus == 'medical';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StudentStatusHistoryScreen(student: s),
                                    ),
                                  );
                                },
                                onLongPress: () => _showLeaveOptions(context, s),
                                leading: CircleAvatar(
                                  backgroundColor: isOnLeave
                                      ? AppTheme.warning.withOpacity(0.2)
                                      : AppTheme.primary.withOpacity(0.2),
                                  child: Text(
                                    s.name.isNotEmpty
                                        ? s.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        color: isOnLeave
                                            ? AppTheme.warning
                                            : AppTheme.primary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(s.name)),
                                    if (isOnLeave)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              AppTheme.warning.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          s.leaveStatus == 'medical'
                                              ? 'Medical'
                                              : 'On Leave',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.warning,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                    '${s.studentId} - Room ${s.roomNo} - ${s.dept}'),
                                trailing: const Icon(
                                    CupertinoIcons.chevron_right),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

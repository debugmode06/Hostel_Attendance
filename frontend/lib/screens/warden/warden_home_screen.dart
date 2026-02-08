import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/app_events.dart';
import '../face_scan_screen.dart';
import '../pending_students_screen.dart';
import '../reports/report_detail_screen.dart';
import '../manage_leave_screen.dart';

class WardenHomeScreen extends StatefulWidget {
  const WardenHomeScreen({super.key});

  @override
  State<WardenHomeScreen> createState() => _WardenHomeScreenState();
}

class _WardenHomeScreenState extends State<WardenHomeScreen> {
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _counts;
  bool _loading = true;
  String? _error;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService().isOnline;
    ConnectivityService().isOnlineStream.listen((v) {
      if (mounted) setState(() => _isOnline = v);
    });
    _load();
    // refresh counts when students change elsewhere
    AppEvents.instance.studentsVersion.addListener(() {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await ApiService().getAttendanceStatus();
      final counts = await ApiService().getStudentCounts();
      if (mounted) {
        setState(() {
          _status = status;
          _counts = counts;
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

  void _startAttendance() {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face scan requires internet connection'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final finalized = _status?['status'] == 'Finalized';
    if (finalized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance finalized for today'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FaceScanScreen()),
    ).then((_) => _load());
  }

  Future<void> _finalizeAttendance() async {
    if (_status?['status'] == 'Finalized') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already finalized'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize Attendance?'),
        content: const Text(
          'This will mark all remaining students as Absent. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ApiService().finalizeAttendance();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance finalized'),
              backgroundColor: AppColors.success,
            ),
          );
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!_isOnline)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.warning, width: 1),
                  ),
                  child: const Text(
                    'Offline',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(CupertinoIcons.square_arrow_right),
            onPressed: () async {
              await AuthService().logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator(radius: 18))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_circle,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CupertinoButton.filled(
                    onPressed: _load,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dashboard cards (premium style)
                    _buildStatCard(
                      'Total Students',
                      '${_counts?['total'] ?? _status?['totalStudents'] ?? 0}',
                      CupertinoIcons.person_2_fill,
                      AppColors.primary,
                    ),
                    const SizedBox(height: 14),
                    _buildStatCard(
                      'Present Today',
                      '${_status?['presentCount'] ?? 0}',
                      CupertinoIcons.checkmark_circle_fill,
                      AppColors.success2,
                    ),
                    const SizedBox(height: 14),
                    _buildStatCard(
                      'Absent Today',
                      '${(((_counts?['total'] ?? _status?['totalStudents'] ?? 0) as int) - (_status?['presentCount'] ?? 0))}',
                      CupertinoIcons.xmark_circle_fill,
                      AppColors.error,
                    ),
                    const SizedBox(height: 32),
                    // Action buttons
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _startAttendance,
                        icon: const Icon(CupertinoIcons.camera_fill),
                        label: const Text(
                          'Start Attendance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _finalizeAttendance,
                        icon: const Icon(CupertinoIcons.checkmark_square),
                        label: const Text(
                          'Finalize Attendance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Secondary actions (grid)
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildActionCard(
                          'Pending',
                          CupertinoIcons.list_bullet,
                          () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => const PendingStudentsScreen(),
                            ),
                          ).then((_) => _load()),
                        ),
                        _buildActionCard(
                          'Leave',
                          CupertinoIcons.airplane,
                          () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => const ManageLeaveScreen(),
                            ),
                          ),
                        ),
                        _buildActionCard(
                          'Reports',
                          CupertinoIcons.doc_text,
                          () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => const ReportDetailScreen(),
                            ),
                          ),
                        ),
                        _buildActionCard(
                          'More',
                          CupertinoIcons.ellipsis,
                          () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

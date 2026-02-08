import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_card.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../reports/report_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _status;
  bool _loading = true;
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
      final status = await ApiService().getAttendanceStatus();
      if (mounted) {
        setState(() {
          _status = status;
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
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: _loading ? null : _load,
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
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppTheme.absent)),
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
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DashboardCard(
                          title: 'Total Students',
                          value: '${_status?['totalStudents'] ?? 0}',
                          icon: CupertinoIcons.person_2_fill,
                        ),
                        const SizedBox(height: 16),
                        DashboardCard(
                          title: 'Today Present',
                          value: '${_status?['presentCount'] ?? 0}',
                          icon: CupertinoIcons.checkmark_circle_fill,
                          color: AppTheme.present,
                        ),
                        const SizedBox(height: 16),
                        DashboardCard(
                          title: 'Attendance Status',
                          value: _status?['status'] ?? '—',
                          icon: CupertinoIcons.doc_text_fill,
                          color: (_status?['status'] == 'Finalized')
                              ? AppTheme.present
                              : AppTheme.warning,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReportDetailScreen(),
                              ),
                            );
                          },
                          icon: const Icon(CupertinoIcons.doc_text),
                          label: const Text('View Reports'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/reports');
                          },
                          icon: const Icon(CupertinoIcons.arrow_down_doc),
                          label: const Text('Export Reports'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

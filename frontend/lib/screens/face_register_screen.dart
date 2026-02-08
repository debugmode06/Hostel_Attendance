import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import '../services/app_events.dart';
import '../widgets/empty_state.dart';
import 'face_register_camera_screen.dart';

class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  List<Student> _students = [];
  List<Student> _filtered = [];
  bool _loading = true;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // reload whenever a face registration or student creation happens elsewhere
    AppEvents.instance.faceRegisterVersion.addListener(() {
      if (mounted) _load();
    });
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
      final list = await ApiService().getStudents(faceRegistered: false);
      final students = list
          .map((e) => Student.fromJson(Map<String, dynamic>.from(e)))
          .toList();
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
        .where(
          (s) =>
              s.studentId.toLowerCase().contains(q) ||
              s.name.toLowerCase().contains(q) ||
              s.roomNo.toLowerCase().contains(q),
        )
        .toList();
  }

  void _openCamera(Student student) async {
    final result = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (_) => FaceRegisterCameraScreen(student: student),
      ),
    );
    if (result == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Face Register'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(
                placeholder: 'Search by name or number...',
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
                  ? const Center(child: CupertinoActivityIndicator(radius: 20))
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(color: AppTheme.absent),
                          ),
                          const SizedBox(height: 16),
                          CupertinoButton(
                            color: AppColors.primary,
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _filtered.isEmpty
                  ? EmptyState.noFacePending()
                  : CustomScrollView(
                      slivers: [
                        CupertinoSliverRefreshControl(onRefresh: _load),
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((_, i) {
                              final s = _filtered[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: CupertinoColors.inactiveGray,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _openCamera(s),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              s.name.isNotEmpty
                                                  ? s.name[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: CupertinoColors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${s.studentId} • Room ${s.roomNo} • ${s.dept}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: CupertinoColors
                                                      .inactiveGray,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          CupertinoIcons.camera_fill,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }, childCount: _filtered.length),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

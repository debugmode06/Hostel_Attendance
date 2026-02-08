import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
  });

  factory EmptyState.noPendingStudents() {
    return const EmptyState(
      emoji: '🎉',
      title: 'No pending students',
      subtitle: 'All students have been marked present',
    );
  }

  factory EmptyState.attendanceFinalized() {
    return const EmptyState(
      emoji: '✅',
      title: 'Attendance finalized for today',
      subtitle: 'No further marking allowed',
    );
  }

  factory EmptyState.noStudents() {
    return const EmptyState(
      emoji: '📋',
      title: 'No students found',
      subtitle: 'Register students to get started',
    );
  }

  factory EmptyState.noFacePending() {
    return const EmptyState(
      emoji: '✨',
      title: 'All faces registered',
      subtitle: 'No students pending face registration',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

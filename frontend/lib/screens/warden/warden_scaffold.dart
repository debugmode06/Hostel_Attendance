import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'warden_home_screen.dart';
import '../registration/registration_screen.dart';
import '../face_register_screen.dart';
import '../reports/reports_list_screen.dart';

class WardenScaffold extends StatefulWidget {
  const WardenScaffold({super.key});

  @override
  State<WardenScaffold> createState() => _WardenScaffoldState();
}

class _WardenScaffoldState extends State<WardenScaffold> {
  int _currentIndex = 0;

  final _screens = [
    const WardenHomeScreen(),
    const RegistrationScreen(),
    const FaceRegisterScreen(),
    const ReportsListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(CupertinoIcons.house),
            selectedIcon: Icon(CupertinoIcons.house_fill),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.person_add),
            selectedIcon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: 'Registration',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.person_crop_circle),
            selectedIcon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: 'Face Register',
          ),
          NavigationDestination(
            icon: Icon(CupertinoIcons.doc_text),
            selectedIcon: Icon(CupertinoIcons.doc_text_fill),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

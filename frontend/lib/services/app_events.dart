import 'package:flutter/foundation.dart';

class AppEvents {
  AppEvents._private();
  static final AppEvents instance = AppEvents._private();

  /// Increment these values to notify listeners to refetch lists/counts.
  final ValueNotifier<int> studentsVersion = ValueNotifier<int>(0);
  final ValueNotifier<int> faceRegisterVersion = ValueNotifier<int>(0);
}

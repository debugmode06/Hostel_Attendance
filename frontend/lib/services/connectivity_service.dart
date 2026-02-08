import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  Stream<bool> get isOnlineStream => _controller.stream;
  bool get isOnline => _isOnline;

  ConnectivityService._() {
    _init();
  }

  Future<void> _init() async {
    _updateStatus(await _connectivity.checkConnectivity());
    _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
    if (wasOnline != _isOnline) {
      _controller.add(_isOnline);
    }
  }
}

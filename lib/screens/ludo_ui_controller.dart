import 'dart:async';
import 'package:flutter/foundation.dart';

class LudoUiController extends ChangeNotifier {
  bool _showGameLog = false;
  bool _isChatInputOpen = false;
  bool _isInteractionMenuOpen = false;
  final Map<int, dynamic> _activeInteractions = {};
  final Map<int, Timer?> _interactionTimers = {};

  bool get showGameLog => _showGameLog;
  bool get isChatInputOpen => _isChatInputOpen;
  bool get isInteractionMenuOpen => _isInteractionMenuOpen;
  Map<int, dynamic> get activeInteractions => _activeInteractions;

  set showGameLog(bool value) {
    if (_showGameLog != value) {
      _showGameLog = value;
      notifyListeners();
    }
  }

  set isChatInputOpen(bool value) {
    if (_isChatInputOpen != value) {
      _isChatInputOpen = value;
      if (value) _isInteractionMenuOpen = false;
      notifyListeners();
    }
  }

  set isInteractionMenuOpen(bool value) {
    if (_isInteractionMenuOpen != value) {
      _isInteractionMenuOpen = value;
      if (value) _isChatInputOpen = false;
      notifyListeners();
    }
  }

  void setActiveInteraction(int pIdx, dynamic data) {
    _interactionTimers[pIdx]?.cancel();
    _activeInteractions[pIdx] = data;
    _isChatInputOpen = false;
    notifyListeners();
  }

  void clearInteractionAfterDelay(int pIdx, Duration delay) {
    _interactionTimers[pIdx]?.cancel();
    _interactionTimers[pIdx] = Timer(delay, () {
      _activeInteractions.remove(pIdx);
      notifyListeners();
    });
  }

  void reset() {
    _activeInteractions.clear();
    for (var timer in _interactionTimers.values) {
      timer?.cancel();
    }
    _interactionTimers.clear();
    _showGameLog = false;
    _isChatInputOpen = false;
    _isInteractionMenuOpen = false;
    notifyListeners();
  }

  void notify() => notifyListeners();

  @override
  void dispose() {
    for (var timer in _interactionTimers.values) {
      timer?.cancel();
    }
    super.dispose();
  }
}

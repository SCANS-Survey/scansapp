import 'dart:async';

typedef GameControllerButtonCallback = void Function(String buttonName);

class GameControllerMonitor {
  static const Set<String> supportedButtons = {'L1', 'R1', 'L2', 'R2'};

  final StreamController<String> _pressedController =
      StreamController<String>.broadcast();

  bool _initialized = false;
  GameControllerButtonCallback? onButtonPressed;

  Stream<String> get pressedButtons => _pressedController.stream;

  GameControllerMonitor({GameControllerButtonCallback? callback}) {
    onButtonPressed = callback;
    initialize();
  }

  void initialize() {
    if (_initialized) {
      return;
    }
    _initialized = true;
  }

  void receiveMessage(String message) {
    print('Game controller message received: $message');
    final button = _normalizeButton(message);
    if (button.isEmpty) {
      return;
    }

    onButtonPressed?.call(button);
    _pressedController.add(button);
  }

  String _normalizeButton(String value) {
    final normalized = value.trim().toUpperCase();
    final clean = normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean == 'L1' || clean == 'R1' || clean == 'L2' || clean == 'R2') {
      return clean;
    }
    return '';
  }

  void dispose() {
    _pressedController.close();
  }
}

final gameController = GameControllerMonitor(
  callback: (buttonName) {
    print('Controller button pressed: $buttonName');
  },
);

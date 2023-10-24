import 'dart:async';
import 'dart:developer' as dev;
import 'package:win32_gamepad/win32_gamepad.dart';

class GamepadControllerWindows {
  Function _updateControlAngles;
  Gamepad? _gamepad;
  GamepadControllerWindows(this._updateControlAngles) {
    _gamepad = Gamepad(0);
    //update controls at 30hz
    Timer.periodic(const Duration(milliseconds: 33), (timer) {
      _gamepad?.updateState();
      _updateControlAngles(
          _gamepad?.state.leftThumbstickX, _gamepad?.state.rightThumbstickX);
    });
  }
}

import 'package:gamepads/gamepads.dart';
import 'dart:async';
import 'dart:developer' as dev;

class GamepadControllerLinux {
  StreamSubscription<GamepadEvent>? _gamepadListener;
  double _rudderStickValue = 0;
  double _trimTabStickValue = 0;
  Function _updateControlAngles;
  GamepadControllerLinux(this._updateControlAngles) {
    _gamepadListener = Gamepads.events.listen((event) {
      dev.log(event.key);
      switch (event.key) {
        case "0": //left stick linux
          // if (!((event.value).abs() > 10000)) {
          //   _rudderStickValue = 0;
          //   return;
          // }
          _rudderStickValue = event.value;
        case "3": //right stick linux
          // if (!((event.value).abs() > 10000)) {
          //   _trimTabStickValue = 0;
          //   return;
          // }
          _trimTabStickValue = event.value;
      }
    });
    //update controls at 30hz
    Timer.periodic(const Duration(milliseconds: 33), (timer) {
      _updateControlAngles(_rudderStickValue, _trimTabStickValue);
    });
  }
  double getRudderStickValue() {
    return _rudderStickValue;
  }

  double getTrimTabStickValue() {
    return _trimTabStickValue;
  }
}

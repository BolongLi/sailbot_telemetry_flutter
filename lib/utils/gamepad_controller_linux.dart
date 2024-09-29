import 'package:gamepads/gamepads.dart';
import 'dart:async';
import 'dart:developer' as dev;


class GamepadControllerLinux {
  StreamSubscription<GamepadEvent>? _gamepadListener;
  Timer? gamePadTimer;
  double _rudderStickValue = 0;
  double _trimTabStickValue = 0;
  bool rudderLock = false;
  bool trimTabLock = false;
  final Function _updateControlAngles;
  GamepadControllerLinux(this._updateControlAngles) {
    _gamepadListener = Gamepads.events.listen((event) {
      dev.log("Key Pressed: ${event.type.name}  ${event.key}");
      String eventString = event.type.name + event.key;
      switch (eventString) {
        case "analog0": //left stick linux      //dev.log(event.key);

          // if (!((event.value).abs() > 10000)) {
          //   _rudderStickValue = 0;
          //   return;
          // }
          if(!rudderLock)_rudderStickValue = event.value;
        case "analog3": //right stick linux
          // if (!((event.value).abs() > 10000)) {
          //   _trimTabStickValue = 0;
          //   return;
          // }
          if(!trimTabLock) _trimTabStickValue = event.value;
        case "analog2":
          //dev.log("Locked Rudder");
          rudderLock = true;
        case "analog5":
          //dev.log("Locked Trim Tab");
          trimTabLock = true;
        case "button4":
          //dev.log("Unlocked Rudder");
          rudderLock = false;
        case "button5":
          //dev.log("Unlocked Trim Tab");
          trimTabLock = false;
      }
    });
    gamePadTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      _updateControlAngles(
          _rudderStickValue.toInt(), _trimTabStickValue.toInt());
    });
  }
  double getRudderStickValue() {
    return _rudderStickValue;
  }

  double getTrimTabStickValue() {
    return _trimTabStickValue;
  }

  void setListen(bool listen){
    if(_gamepadListener != null){
      if(listen && _gamepadListener!.isPaused){
        _gamepadListener!.resume();
        dev.log("Started gamepad listener");
            //update controls at 30hz
        //update controls at 30hz
        gamePadTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
          _updateControlAngles(
              _rudderStickValue.toInt(), _trimTabStickValue.toInt());
        });
      }
      else if(!listen && !_gamepadListener!.isPaused){
        _gamepadListener!.pause();
        dev.log("Stopped gamepad listener");
        if(gamePadTimer != null){
          dev.log("Stopped timer");
          gamePadTimer!.cancel();
        }
      }
    }
  }
}

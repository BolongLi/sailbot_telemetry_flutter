import 'package:gamepads/gamepads.dart';
import 'dart:async';
import 'dart:developer' as dev;


/* TODO
  Letter buttons for auto sate control
  Lock controls in app - change their angles to reflect that of the boat
      Add this for auto as well
   -Just do whenever they are locked they mirror the boats actual state
  
*/  

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
      String eventString = event.type.name + event.key;
        switch (eventString) {
          case "analog0": //left stick linux
            if(!rudderLock)_rudderStickValue = event.value;
          case "analog3": //right stick linux
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
          case "button3": //y full manual

          case "button2": //x auto rudder

          case "button0": //a auto trimtab

          case "button1": //b ful auto

          case "button5":
            //dev.log("Unlocked Trim Tab");
            trimTabLock = false;
            
        }
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
      if(listen){
        //_gamepadListener!.resume();
        dev.log("Started gamepad listener");

      _gamepadListener = Gamepads.events.listen((event) {
      String eventString = event.type.name + event.key;
        switch (eventString) {
          case "analog0": //left stick linux      //dev.log(event.key);
            if(!rudderLock)_rudderStickValue = event.value;
          case "analog3": //right stick linux
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
        //update controls at 30hz
        gamePadTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
          _updateControlAngles(
              _rudderStickValue.toInt(), _trimTabStickValue.toInt());
        });
      }
      else if(!listen){
        _gamepadListener!.cancel();
        dev.log("Stopped gamepad listener");
        if(gamePadTimer != null){
          dev.log("Stopped timer");
          gamePadTimer!.cancel();
        }
      }
    }
  }
}

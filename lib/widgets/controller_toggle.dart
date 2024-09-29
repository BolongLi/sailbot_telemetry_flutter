import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/gamepad_controller_linux.dart';
import 'dart:developer' as dev;

final controllerState = StateProvider<bool>((ref) => false);


class ControllerToggle extends ConsumerWidget {
  ControllerToggle({super.key}); 
  NetworkComms? _networkComms;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastcontrollerState = ref.watch(controllerState);
    _networkComms = ref.watch(networkCommsProvider);

    return Switch(
    value: lastcontrollerState, 
    onChanged: (bool value){
      dev.log("Setting up switch");

      //toggle controller control
      ref.read(controllerState.notifier).state = value;
      final gamePadController = GamepadControllerLinux(_updateControlAngles);

      if(value){
        dev.log("Controller on");
        gamePadController.setListen(true);
      }
      else{
        gamePadController.setListen(false);
        dev.log("Controller off");
      }
    },
    );
  }

  void _updateControlAngles(int rudderStickValue, int trimTabStickValue) {
  double rudderAngle = (rudderStickValue / 32767) * 1.5;
  double trimTabAngle = (trimTabStickValue / 32767) * 1.5;
  _networkComms?.setRudderAngle(rudderAngle);
  _networkComms?.setTrimtabAngle(trimTabAngle);
  }
}


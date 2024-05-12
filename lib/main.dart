import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/utils/utils.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/nodes_drawer.dart';
import 'package:sailbot_telemetry_flutter/widgets/settings_drawer.dart';
import 'package:sailbot_telemetry_flutter/widgets/drawer_icon_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/settings_icon_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/draggable_circle.dart';
import 'package:sailbot_telemetry_flutter/widgets/autonomous_mode_selector.dart';
import 'package:sailbot_telemetry_flutter/widgets/trim_state_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/ballast_slider.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';

import 'dart:developer' as dev;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: MyApp()));
}

final GlobalKey<ScaffoldState> _scaffoldState = GlobalKey<ScaffoldState>();

class MyApp extends ConsumerWidget {
  MyApp({super.key});

  NetworkComms? _networkComms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _networkComms = ref.watch(networkCommsProvider);

    final trimTabKey = GlobalKey<CircleDragWidgetState>();
    final trimTabControlWidget = CircleDragWidget(
      width: 150,
      height: 75,
      lineLength: 60,
      radius: 7,
      resetOnRelease: false,
      isInteractive: true,
      callback: _updateTrimtabAngle,
      key: trimTabKey,
    );

    final rudderKey = GlobalKey<CircleDragWidgetState>();
    final rudderControlWidget = CircleDragWidget(
      width: 150,
      height: 75,
      lineLength: 60,
      radius: 7,
      resetOnRelease: true,
      isInteractive: true,
      callback: _updateRudderAngle,
      key: rudderKey,
    );

    ref.listen<String>(autonomousModeProvider, (_, selectedMode) {
      if (selectedMode == 'NONE') {
        dev.log('Manual control');
        _networkComms?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_NONE);

        trimTabControlWidget.setInteractive(true);
        rudderControlWidget.setInteractive(true);
      } else if (selectedMode == 'BALLAST') {
        dev.log('Auto ballast');
        _networkComms
            ?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_BALLAST);

        trimTabControlWidget.setInteractive(true);
        rudderControlWidget.setInteractive(true);
      } else if (selectedMode == 'TRIMTAB') {
        dev.log('auto trimtab');
        _networkComms
            ?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_TRIMTAB);
        trimTabControlWidget.setInteractive(false);
        rudderControlWidget.setInteractive(true);
      } else if (selectedMode == 'FULL') {
        dev.log('Full auto');
        _networkComms?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_FULL);

        trimTabControlWidget.setInteractive(false);
        rudderControlWidget.setInteractive(false);
      }
    });

    return MaterialApp(
      title: "Sailbot Telemetry",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
          drawer: const NodesDrawer(),
          endDrawer: const SettingsDrawer(),
          key: _scaffoldState,
          body: Stack(children: [
            const Flex(direction: Axis.horizontal, children: <Widget>[
              Flexible(child: MapCameraWidget()),
            ]),
            DrawerIconWidget(_scaffoldState),
            Align(
                alignment: Alignment.topRight,
                child: SettingsIconWidget(_scaffoldState)),
            Transform.translate(
              offset: Offset(displayWidth(context) / 9, -40),
              child: Align(
                alignment: Alignment.bottomLeft,
                // centerPoint:
                //     Offset(displayWidth(context) / 2, displayHeight(context) / 2),
                child: rudderControlWidget,
              ),
            ),
            Transform.translate(
              offset: Offset(-displayWidth(context) / 9, -40),
              child: Align(
                alignment: Alignment.bottomRight,
                // centerPoint:
                //     Offset(displayWidth(context) / 2, displayHeight(context) / 2),
                child: trimTabControlWidget,
              ),
            ),
            Transform.translate(
                offset: Offset(0, displayHeight(context) / 2 - 180),
                child: const Align(
                    //alignment: Alignment.bottomCenter,
                    child: SizedBox(
                        height: 40, width: 300, child: BallastSlider()))),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                transform: Matrix4.translationValues(0, 120.0, 0),
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey),
                ),
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  const TrimStateWidget(),
                  const Divider(
                    color: Colors.grey,
                    thickness: 1,
                    indent: 5,
                    endIndent: 5,
                  ),
                  AutonomousModeSelector(),
                ]),
              ),
            ),
          ])),
    );
  }

  _updateRudderAngle(double angle) {
    _networkComms?.setRudderAngle(angle);
  }

  _updateTrimtabAngle(double angle) {
    _networkComms?.setTrimtabAngle(angle);
  }
}

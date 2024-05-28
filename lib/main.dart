import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/utils/utils.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/startup_manager.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/nodes_drawer.dart';
import 'package:sailbot_telemetry_flutter/widgets/settings_drawer.dart';
import 'package:sailbot_telemetry_flutter/widgets/drawer_icon_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/settings_icon_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/draggable_circle.dart';
import 'package:sailbot_telemetry_flutter/widgets/autonomous_mode_selector.dart';
import 'package:sailbot_telemetry_flutter/widgets/trim_state_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/ballast_slider.dart';
import 'package:sailbot_telemetry_flutter/widgets/path_point.dart';
import 'package:sailbot_telemetry_flutter/widgets/path_buttons.dart';
import 'package:sailbot_telemetry_flutter/widgets/video_source_select.dart';
import 'package:sailbot_telemetry_flutter/widgets/heading_speed_display.dart';
import 'package:sailbot_telemetry_flutter/widgets/wind_direction_display.dart';
import 'package:sailbot_telemetry_flutter/widgets/align_positioned.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/widgets/rudder_control_widget.dart';

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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    ref.listen<AsyncValue<List<Server>>>(serverListProvider, (previous, next) {
      next.when(
        loading: () {},
        error: (error, stackTrace) {},
        data: (servers) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedServerProvider.notifier).state = servers[0];
            dev.log("3. Setting current server to: ${servers[0].name}");
          });
        },
      );
    });

    ref.listen<NetworkComms?>(networkCommsProvider, (_, networkComms) {
      _networkComms = networkComms;
      ref.read(autonomousModeProvider.notifier).state = 'NONE';
    });
    _networkComms = ref.watch(networkCommsProvider);
    ref.read(ros2NetworkCommsProvider.notifier).initialize();
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

    final rudderControlWidget = RudderControlWidget();

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
      // Disable Android's jank-ass overscroll animation
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: CustomScrollBehavior(),
          child: child!,
        );
      },
      home: Scaffold(
          drawer: const NodesDrawer(),
          endDrawer: const SettingsDrawer(),
          key: _scaffoldState,
          body: Stack(children: [
            const Flex(direction: Axis.horizontal, children: <Widget>[
              Flexible(child: MapCameraWidget()),
            ]),
            const Align(
              alignment: Alignment.centerRight,
              child: MapCameraToggle(),
            ),
            DrawerIconWidget(_scaffoldState),
            AlignPositioned(
                alignment: Alignment.bottomCenter,
                centerPoint: Offset(displayWidth(context) / 1.5, 0),
                child: const HeadingSpeedDisplay()),
            AlignPositioned(
                alignment: Alignment.centerRight,
                centerPoint: Offset(0, displayHeight(context) / 2),
                child: const WindDirectionDisplay()),
            Align(
                alignment: Alignment.topRight,
                child: SettingsIconWidget(_scaffoldState)),
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
            const PathPoint(),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                transform: Matrix4.translationValues(0, -60.0, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey),
                ),
                child: VideoSourceSelect(),
              ),
            ),
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
                offset: Offset(displayWidth(context)/2-180, displayHeight(context) - 180),
                    child: SizedBox(
                        height: 40,
                        width: 450,
                        child: Row(children: <Widget>[
                          FloatingActionButton(
                              onPressed: (){_networkComms?.requestTack();},
                              child: const Text("Tack")),
                          const SizedBox(
                        height: 40,
                        width: 250,
                        child: BallastSlider())
                        ]))),
            PathButtons(),
          ])),
    );
  }

  _updateTrimtabAngle(double angle) {
    _networkComms?.setTrimtabAngle(angle);
  }
}

class CustomScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Theme.of(context).primaryColor,
      child: child,
    );
  }
}

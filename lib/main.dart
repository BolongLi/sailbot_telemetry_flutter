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
        body: Stack(
        children: [
          const Flex(direction: Axis.horizontal, children: <Widget>[
            Flexible( child: MapCameraWidget()),]),
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
          ),])
      ),
    );
  }
  _updateRudderAngle(double angle) {
    _networkComms?.setRudderAngle(angle);
  }

  _updateTrimtabAngle(double angle) {
    _networkComms?.setTrimtabAngle(angle);
  }
}

class NetworkCommsConsumerWidget extends ConsumerWidget {
  const NetworkCommsConsumerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkComms = ref.watch(networkCommsProvider);

    return Scaffold(
      body: Center(
        child: Text(networkComms != null ? 'NetworkComms is initialized' : 'NetworkComms is null'),
      ),
    );
  }
}
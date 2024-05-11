import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/nodes_drawer.dart';
import 'package:sailbot_telemetry_flutter/widgets/settings_drawer.dart';
import 'package:sailbot_telemetry_flutter/widgets/drawer_icon_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/settings_icon_widget.dart';
import 'dart:developer' as dev;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

final GlobalKey<ScaffoldState> _scaffoldState = GlobalKey<ScaffoldState>();

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

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
            child: SettingsIconWidget(_scaffoldState))])
      ),
    );
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
import 'dart:math';

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
import 'package:gamepads/gamepads.dart';
import 'dart:async';


import 'dart:developer' as dev;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: MyApp()));
}

final GlobalKey<ScaffoldState> _scaffoldState = GlobalKey<ScaffoldState>();

class ModeEdge {
  bool isPressed = false;
  DateTime lastFire = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration cooldown = const Duration(milliseconds: 200);
  final double pressHigh;   // e.g. 0.6
  final double releaseLow;  // e.g. 0.4

  ModeEdge({this.pressHigh = 0.6, this.releaseLow = 0.4});

  // Call this for each analog event from your "button 4" axis
  // raw can be int (-32768..32767) or double (-1..1 or 0..1)
  bool update(num raw) {
    final v = _normalize(raw);      // -> [0..1] makes thresholds easy
    final now = DateTime.now();

    // Rising edge: not pressed -> pressed
    if (!isPressed && v >= pressHigh) {
      // Debounce
      if (now.difference(lastFire) >= cooldown) {
        isPressed = true;
        lastFire = now;
        // print("hit");
        return true; // FIRE: one press detected
      }
    }

    // Falling edge: pressed -> released
    if (isPressed && v <= releaseLow) {
      isPressed = false;
    }
    return false; // no new press
  }

  double _normalize(num raw) {
    // Common cases:
    // - int axis: -32768..32767  (triggers sometimes rest at -32768)
    // - double axis: -1..1 or 0..1
    double v;
    if (raw is int) {
      v = raw / 32767.0; // now ~[-1..1]
    } else {
      v = raw.toDouble(); // assume already normalized
    }

    // If trigger rests near -1 and increases to +1, remap to [0..1]:
    // Adjust this depending on your device—if yours is already [0..1], just return v.
    final vv = ((v + 1.0) / 2.0).clamp(0.0, 1.0);
    return vv;
  }
}


class InputController {
  // Pressed states
  bool rudderLeft = false;
  bool rudderRight = false;
  bool trimtabLeft = false;
  bool trimtabRight = false;
  bool centerRudder = false;
  bool centerTrim = false;
  int mode = 1;
  final modeEdge = ModeEdge(pressHigh: 0.6, releaseLow: 0.4);
  bool lockRudder = false;
  bool lockTrim   = false;

  StreamSubscription? _sub;
  Timer? _tick;
  double rudderAngle = 0.0;
  double trimtabAngle = 0.0;

  // External callbacks (inject your NetworkComms)
  void Function(double)? onRudder;
  void Function(double)? onTrimtab;
  void Function()? onTack;
  void Function(String)? onAutoMode;

  // Call once (e.g., in main widget init or provider init)
  void start() {
    // 1) Listen to events -> update pressed/axis states
    _sub = Gamepads.events.listen((event) {
      final k = event.key.toString();
      final v = event.value; // 0/1 for buttons, or analog for axes

      // SAFETY: Only act on buttons you care about.
      // Map your button numbers clearly (example mapping):
      // '6' = rudderRight, '7' = rudderLeft
      // '1' = trimtabRight, '3' = trimtabLeft
      // '10' = center rudder, '2' = center trim

      if (k == '6') rudderRight = (v == 1);
      if (k == '7') rudderLeft  = (v == 1);

      if (k == '1') trimtabRight = (v == 1);
      if (k == '3') trimtabLeft  = (v == 1);

      if (k == '10') centerRudder = (v == 1);
      if (k == '11')  centerTrim   = (v == 1);

      if(k == '5'){
        if (modeEdge.update(event.value)) {   // true only on rising edge (debounced)
          // print("TACK!");
          onTack?.call();
          centerRudder = true; // auto center rudder on tack
          centerTrim = true;   // auto center trimtab on tack
        }

         }

      if (event.key == '4') {                  
        if (modeEdge.update(event.value)) {   // true only on rising edge (debounced)
          mode += 1;
          if (mode > 4) mode = 1;
          if (mode == 1) onAutoMode?.call('NONE');
          if (mode == 2) onAutoMode?.call('BALLAST');
          if (mode == 3) onAutoMode?.call('TRIMTAB');
          if (mode == 4) onAutoMode?.call('FULL');
          // applyMode(mode == 1 ? 'NONE' : mode == 2 ? 'BALLAST' : mode == 3 ? 'TRIMTAB' : 'FULL'); 
        }
      }


    });

    const dt = Duration(milliseconds: 33); // ~30 FPS 
    _tick = Timer.periodic(dt, (_) {
      const step = 0.15; // increment per tick; tune this
      const minAngle = -1.5;
      const maxAngle =  1.5;

      // === Rudder ===
      if (lockRudder) {
        // Center once and only send if changed (avoid spamming)
        if (rudderAngle != 0.0) {
          rudderAngle = 0.0;
          onRudder?.call(rudderAngle);
        }
      } else {
        // apply manual increments from pressed flags
        if (centerRudder) rudderAngle = 0.0;
        if (rudderRight) rudderAngle += step;
        if (rudderLeft)  rudderAngle -= step;
        rudderAngle = rudderAngle.clamp(minAngle, maxAngle);
        onRudder?.call(rudderAngle);
      }

      // === Trimtab ===
      if (lockTrim) {
        if (trimtabAngle != 0.0) {
          trimtabAngle = 0.0;
          onTrimtab?.call(trimtabAngle);
        }
      } else {
        if (centerTrim)   trimtabAngle = 0.0;
        if (trimtabRight) trimtabAngle += step;
        if (trimtabLeft)  trimtabAngle -= step;
        trimtabAngle = trimtabAngle.clamp(minAngle, maxAngle);
        onTrimtab?.call(trimtabAngle);
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _tick?.cancel();
    _tick = null;
  }

  // Call this when mode or tack changes:
  void applyMode(String mode) {
    if (mode == 'NONE') {
      lockRudder = false;
      lockTrim   = false;
    } else if (mode == 'BALLAST') {
      lockRudder = false;
      lockTrim   = false;
    } else if (mode == 'TRIMTAB') {
      lockRudder = false; // manual rudder OK
      lockTrim   = true;  // auto controls trim
    } else if (mode == 'FULL') {
      lockRudder = true;
      lockTrim   = true;
    }

    // Optional: immediately center when entering locks
    if (lockRudder) { rudderAngle = 0.0; onRudder?.call(0.0); }
    if (lockTrim)   { trimtabAngle = 0.0; onTrimtab?.call(0.0); }
    print("Mode $mode: lockRudder=$lockRudder lockTrim=$lockTrim"); 
  }

  // If you press "Tack", you may want to lock both during the maneuver
  void beginTack() {
    lockRudder = true;
    lockTrim   = true;
    rudderAngle = 0.0;
    trimtabAngle = 0.0;
    onRudder?.call(0.0);
    onTrimtab?.call(0.0);
    onTack?.call();
  }

  // Call this when robot reports tack finished (via NetworkComms callback)
  void endTack(String currentMode) {
    applyMode(currentMode); // restore locks based on current mode
  }

}

// Riverpod provider
final inputControllerProvider = Provider<InputController>((ref) {
  final c = InputController();
  ref.onDispose(c.stop);
  return c;
});


class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}


class _MyAppState extends ConsumerState<MyApp> {
  NetworkComms? _networkComms;
  final GlobalKey<CircleDragWidgetState> _trimTabKey =GlobalKey<CircleDragWidgetState>();
  late final RudderControlWidget _rudderControlWidget = RudderControlWidget();
  late final CircleDragWidget _trimTabControlWidget = CircleDragWidget(
  width: 150,
  height: 75,
  lineLength: 60,
  radius: 7,
  resetOnRelease: false,
  isInteractive: true,
  callback: _updateTrimtabAngle,
  key: _trimTabKey,
  );
  
  @override
  void initState() {
    super.initState();

    final ic = ref.read(inputControllerProvider);

    // Inject callbacks to talk to your network layer
    ic.onRudder = (angle) => _updateRudderAngle(angle); // _networkComms?.setRudderAngle(angle);
    ic.onTrimtab = (angle) => _updateTrimtabAngle(angle); // _networkComms?.setTrimtabAngle(angle);
    ic.onTack = () => _networkComms?.requestTack();
    ic.onAutoMode = (mode) {
      final notifier = ref.read(autonomousModeProvider.notifier);
      notifier.state = mode; // 'NONE' | 'BALLAST' | 'TRIMTAB' | 'FULL'
      ic.applyMode(mode);
    };

    ic.start(); // begin listening + ticking
  }

  @override
  void dispose() {
    ref.read(inputControllerProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    // this is only used to reset the autonomous mode to NONE when we reconnect, comment out when we don't have a robot to connect to
    // because it gets called on every try of rebuild connection which is very often

    // ref.listen<NetworkComms?>(networkCommsProvider, (_, networkComms) {
    //   _networkComms = networkComms;
    //   ref.read(autonomousModeProvider.notifier).state = 'NONE';
    // });
    _networkComms = ref.watch(networkCommsProvider);
    ref.read(ros2NetworkCommsProvider.notifier).initialize();
    // final trimTabKey = GlobalKey<CircleDragWidgetState>();
    final trimTabControlWidget = _trimTabControlWidget;// CircleDragWidget(
    //   width: 150,
    //   height: 75,
    //   lineLength: 60,
    //   radius: 7,
    //   resetOnRelease: false,
    //   isInteractive: true,
    //   callback: _updateTrimtabAngle,
    //   key: _trimTabKey,
    // );

    final rudderControlWidget = _rudderControlWidget;

    ref.listen<String>(autonomousModeProvider, (_, selectedMode) {
      print(selectedMode);
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

    Gamepads.events.listen((event) {
      // ...
      // print(event.key);
      // print(event.value);
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
                offset: Offset(displayWidth(context) / 2 - 180,
                    displayHeight(context) - 240),
                child: SizedBox(
                  height: 70,
                  width: 90,
                  child: FloatingActionButton(
                      onPressed: () {
                        _networkComms?.requestTack();
                      },
                      child: const Text("Tack")),
                  // const SizedBox(
                  //     height: 40, width: 250, child: BallastSlider())
                )),
            PathButtons(),
          ])),
    );
  }

  _updateTrimtabAngle(double angle) {
    _trimTabControlWidget.setAngle(angle);
    _networkComms?.setTrimtabAngle(angle);
  }

  _updateRudderAngle(double angle) {
    _rudderControlWidget.setAngle(angle);
    _networkComms?.setRudderAngle(angle);
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

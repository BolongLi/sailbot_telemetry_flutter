import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/widgets/drawer.dart';
import 'package:latlong2/latlong.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'dart:math';
import 'dart:developer' as dev; //log() conflicts with math
import 'dart:async';
import 'package:sailbot_telemetry_flutter/widgets/align_positioned.dart';
import 'dart:io' as io;
import 'package:sailbot_telemetry_flutter/utils/utils.dart';
import 'package:sailbot_telemetry_flutter/widgets/draggable_circle.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/gamepad_controller_linux.dart';

GlobalKey<ScaffoldState> _scaffoldState = GlobalKey<ScaffoldState>();

class MapPage extends StatefulWidget {
  static const String route = '/polyline';

  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  double _speed = 0.0;
  double _heading = 0.0;
  double _trueWind = 0.0;
  double _apparentWind = 0.0;
  LatLng _boatLatLng = LatLng(51.5, -0.09);
  final Color _colorOk = const Color.fromARGB(255, 0, 0, 0);
  final Color _colorWarn = const Color.fromARGB(255, 255, 129, 10);
  final Color _colorError = const Color.fromARGB(255, 255, 0, 0);
  Color _menuIconColor = const Color.fromARGB(255, 0, 0, 0);
  final Color _connectionColorOK = const Color.fromARGB(255, 0, 255, 0);
  Color _connectionIconColor = const Color.fromARGB(255, 0, 0, 0);
  int _lastConnectionTime = DateTime.now().millisecondsSinceEpoch - 3000;
  var _nodeStates = <NodeInfo>[];
  var _polylines = <Polyline>[];
  DateTime _lastTime = DateTime.now();

  NetworkComms? networkComms;
  //Socket? _socket;
  final int retryDuration = 1; // duration in seconds
  final int connectionTimeout = 1; // timeout duration in seconds

  final _compassAnnotations = const <GaugeAnnotation>[
    GaugeAnnotation(
      axisValue: 270,
      positionFactor: 0.6,
      widget: Text('W', style: TextStyle(fontSize: 16)),
    ),
    GaugeAnnotation(
      axisValue: 90,
      positionFactor: 0.6,
      widget: Text('E', style: TextStyle(fontSize: 16)),
    ),
    GaugeAnnotation(
      axisValue: 0,
      positionFactor: 0.6,
      widget: Text('N', style: TextStyle(fontSize: 16)),
    ),
    GaugeAnnotation(
      axisValue: 180,
      positionFactor: 0.6,
      widget: Text('S', style: TextStyle(fontSize: 16)),
    ),
  ];

  CircleDragWidget? _trimTabControlWidget;
  final trimTabKey = GlobalKey<CircleDragWidgetState>();
  CircleDragWidget? _rudderControlWidget;
  final rudderKey = GlobalKey<CircleDragWidgetState>();

  Map<String, DropdownMenuEntry<String>> _servers = HashMap();
  String? _selectedValue;

  @override
  void initState() {
    super.initState();

    //control widgets
    _trimTabControlWidget = CircleDragWidget(
      width: 100,
      height: 50,
      lineLength: 40,
      radius: 5,
      callback: _updateTrimtabAngle,
      key: trimTabKey,
    );
    _rudderControlWidget = CircleDragWidget(
      width: 100,
      height: 50,
      lineLength: 40,
      radius: 5,
      callback: _updateRudderAngle,
      key: rudderKey,
    );

    _servers["172.29.201.10"] =
        DropdownMenuEntry(value: "172.29.201.10", label: "sailbot-nano");
    _servers["172.29.81.241"] =
        DropdownMenuEntry(value: "172.29.81.241", label: "sailbot-orangepi");
    _selectedValue = _servers.values.first.value;
    setState(() {
      //update servers list
    });
    //gRPC client
    networkComms = NetworkComms(receiveBoatState, "172.29.81.241");
    //dev.log("Created comms object", name: "network");("172.29.81.241");

    //controller
    // if (io.Platform.isLinux) {}
    GamepadController(_updateControlAngles);

    Timer.periodic(const Duration(seconds: 1), (timer) {
      _connectionIconColorCallback();
    });
  }

  @override
  void dispose() {
    //_gamepadListener?.cancel();
    super.dispose();
  }

  void _resetComms(String server) async {
    networkComms?.reconnect(server);
  }

  _updateRudderAngle(double angle) {
    networkComms?.updateRudderAngle(angle);
  }

  _updateTrimtabAngle(double angle) {
    networkComms?.updateTrimtabAngle(angle);
  }

  void _updateControlAngles(rudderStickValue, trimTabStickValue) {
    DateTime currentTime = DateTime.now();
    double rudderScalar = (rudderStickValue) / 32768;
    double rudderAngleChange = (currentTime.millisecondsSinceEpoch -
            _lastTime.millisecondsSinceEpoch) /
        1000 *
        rudderScalar;
    bool refresh = false;
    if (rudderAngleChange != 0) {
      refresh = true;
      _rudderControlWidget?.incrementAngle(rudderAngleChange);
    }

    double ttScalar = (trimTabStickValue) / 32768;
    double ttAngleChange = (currentTime.millisecondsSinceEpoch -
            _lastTime.millisecondsSinceEpoch) /
        1000 *
        ttScalar;
    if (ttAngleChange != 0) {
      refresh = true;
      _trimTabControlWidget?.incrementAngle(ttAngleChange);
    }
    _lastTime = currentTime;
    if (refresh) {
      setState(() {});
    }
  }

  void _connectionIconColorCallback() {
    setState(() {
      DateTime currentTime = DateTime.now();
      if (currentTime.millisecondsSinceEpoch - _lastConnectionTime > 3000) {
        _connectionIconColor = _colorError;
      } else {
        _connectionIconColor = _connectionColorOK;
      }
    });
  }

  receiveBoatState(BoatState boatState) {
    setState(() {
      DateTime currentTime = DateTime.now();
      _lastConnectionTime = currentTime.millisecondsSinceEpoch;
      _heading = boatState.currentHeading;
      _speed = boatState.speedKnots;
      _trueWind = boatState.trueWind.direction;
      _apparentWind = boatState.apparentWind.direction;
      _nodeStates = boatState.nodeStates;
      _boatLatLng = LatLng(boatState.latitude, boatState.longitude);

      //path lines
      _polylines.clear();
      var boatPoints = boatState.currentPath.points;
      var points = <LatLng>[];
      if (boatPoints.isNotEmpty) {
        points.add(_boatLatLng);
      }
      for (var point in boatPoints) {
        points.add(LatLng(point.latitude, point.longitude));
      }
      _polylines.add(Polyline(
        points: points,
        strokeWidth: 4,
        color: Colors.blue.withOpacity(0.6),
        borderStrokeWidth: 6,
        borderColor: Colors.red.withOpacity(0.4),
      ));

      bool allOk = true;
      bool error = false;
      bool warn = false;
      for (NodeInfo status in boatState.nodeStates) {
        if (status.status == NodeStatus.NODE_STATUS_ERROR) {
          allOk = false;
          error = true;
        }
        if (status.status == NodeStatus.NODE_STATUS_WARN) {
          allOk = false;
          warn = true;
        }
      }
      if (allOk) {
        _menuIconColor = _colorOk;
      } else {
        if (warn) _menuIconColor = _colorWarn;
        if (error) _menuIconColor = _colorError;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildDrawer(context, MapPage.route, _nodeStates),
      endDrawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Text('Drawer Header'),
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
            ),
            ListTile(
              title: Row(children: <Widget>[
                DropdownMenu<String>(
                  dropdownMenuEntries: _servers.values.toList(),
                  initialSelection: _selectedValue,
                  requestFocusOnTap: false,
                  onSelected: (dynamic newValue) {
                    dev.log("connecting to: $newValue", name: 'network');
                    setState(() {
                      _selectedValue = newValue;
                    });
                    _resetComms(newValue);
                  },
                ),
              ]),
            ),
          ],
        ),
      ),
      key: _scaffoldState,
      body: Stack(
        children: [
          Flex(direction: Axis.horizontal, children: <Widget>[
            Flexible(
              child: FlutterMap(
                options: MapOptions(
                    initialCenter: const LatLng(51.5, -0.09),
                    initialZoom: 5,
                    interactionOptions: InteractionOptions(
                        flags: InteractiveFlag.all - InteractiveFlag.rotate,
                        cursorKeyboardRotationOptions:
                            CursorKeyboardRotationOptions(
                          isKeyTrigger: (key) => false,
                        ))),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'dev.wpi.sailbot.sailbot_telemetry',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                        point: _boatLatLng,
                        height: 60,
                        width: 60,
                        child: Transform.rotate(
                            angle: _heading * pi / 180,
                            child: Image.asset("assets/arrow.png"))),
                    Marker(
                        point: _boatLatLng,
                        height: 30,
                        width: 30,
                        child: Image.asset("assets/boat.png"))
                  ]),
                  PolylineLayer(polylines: _polylines),
                ],
              ),
            ),
          ]),
          AlignPositioned(
            alignment: Alignment.bottomCenter,
            centerPoint: Offset(displayWidth(context) / 1.5, 0),
            //width: min(displayWidth(context) / 3, 200),
            child: Row(
              children: <Widget>[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                        width: min(displayWidth(context) / 3, 150),
                        height: min(displayWidth(context) / 3, 150),
                        child:
                            _buildCompassGauge(_heading, _compassAnnotations)),
                    const Text("heading"),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                        width: min(displayWidth(context) / 3, 150),
                        height: min(displayWidth(context) / 3, 150),
                        child: _buildSpeedGauge()),
                    const Text("Speed"),
                  ],
                ),
              ],
            ),
          ),
          AlignPositioned(
            alignment: Alignment.centerRight,
            centerPoint: Offset(0, displayHeight(context) / 2),
            //width: min(displayWidth(context) / 3, 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text("True wind"),
                SizedBox(
                    width: min(displayHeight(context) / 3, 150),
                    height: min(displayHeight(context) / 3, 150),
                    child: _buildCompassGauge(_trueWind, _compassAnnotations)),
                const Text("Apparent wind"),
                SizedBox(
                    width: min(displayHeight(context) / 3, 150),
                    height: min(displayHeight(context) / 3, 150),
                    child: _buildCompassGauge(_apparentWind, null)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            color: _menuIconColor,
            onPressed: () {
              _scaffoldState.currentState?.openDrawer();
            },
          ),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.wifi),
              color: _connectionIconColor,
              onPressed: () {
                _scaffoldState.currentState?.openEndDrawer();
              },
            ),
          ),
          Transform.translate(
            offset: const Offset(-40, -40),
            child: Align(
              alignment: Alignment.bottomCenter,
              // centerPoint:
              //     Offset(displayWidth(context) / 2, displayHeight(context) / 2),
              child: _rudderControlWidget,
            ),
          ),
          Transform.translate(
            offset: const Offset(-40, -40),
            child: Align(
              alignment: Alignment.bottomRight,
              // centerPoint:
              //     Offset(displayWidth(context) / 2, displayHeight(context) / 2),
              child: _trimTabControlWidget,
            ),
          ),
        ],
      ),
    );
  }

  SfRadialGauge _buildSpeedGauge() {
    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          startAngle: 180,
          endAngle: 0,
          minimum: 0,
          maximum: 20,
          interval: 5,
          majorTickStyle: const MajorTickStyle(
            length: 0.16,
            lengthUnit: GaugeSizeUnit.factor,
            thickness: 1.5,
          ),
          minorTickStyle: const MinorTickStyle(
            length: 0.16,
            lengthUnit: GaugeSizeUnit.factor,
          ),
          minorTicksPerInterval: 10,
          showLabels: true,
          showTicks: true,
          ticksPosition: ElementsPosition.outside,
          labelsPosition: ElementsPosition.outside,
          offsetUnit: GaugeSizeUnit.factor,
          labelOffset: -0.2,
          radiusFactor: 0.75,
          showLastLabel: false,
          pointers: <GaugePointer>[
            NeedlePointer(
              value: _speed,
              enableDragging: false,
              needleLength: 0.7,
              lengthUnit: GaugeSizeUnit.factor,
              needleStartWidth: 1,
              needleEndWidth: 1,
              needleColor: const Color(0xFFD12525),
              knobStyle: const KnobStyle(
                knobRadius: 0.1,
                color: Color(0xffc4c4c4),
              ),
              tailStyle: const TailStyle(
                lengthUnit: GaugeSizeUnit.factor,
                length: 0,
                width: 1,
                color: Color(0xffc4c4c4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  SfRadialGauge _buildCompassGauge(
      var valueSource, List<GaugeAnnotation>? annotations) {
    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          startAngle: 270,
          endAngle: 270,
          minimum: 0,
          maximum: 360,
          interval: 30,
          majorTickStyle: const MajorTickStyle(
            length: 0.16,
            lengthUnit: GaugeSizeUnit.factor,
            thickness: 1.5,
          ),
          minorTickStyle: const MinorTickStyle(
            length: 0.16,
            lengthUnit: GaugeSizeUnit.factor,
          ),
          minorTicksPerInterval: 10,
          showLabels: true,
          showTicks: true,
          ticksPosition: ElementsPosition.outside,
          labelsPosition: ElementsPosition.outside,
          offsetUnit: GaugeSizeUnit.factor,
          labelOffset: -0.2,
          radiusFactor: 0.75,
          showLastLabel: false,
          pointers: <GaugePointer>[
            NeedlePointer(
              value: valueSource,
              enableDragging: false,
              needleLength: 0.7,
              lengthUnit: GaugeSizeUnit.factor,
              needleStartWidth: 1,
              needleEndWidth: 1,
              needleColor: const Color(0xFFD12525),
              knobStyle: const KnobStyle(
                knobRadius: 0.1,
                color: Color(0xffc4c4c4),
              ),
              tailStyle: const TailStyle(
                lengthUnit: GaugeSizeUnit.factor,
                length: 0.7,
                width: 1,
                color: Color(0xffc4c4c4),
              ),
            ),
          ],
          annotations: annotations,
        ),
      ],
    );
  }
}

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart'
    as boat_state;
import 'package:sailbot_telemetry_flutter/utils/gamepad_controller_windows.dart';
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
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart'
    as github_helper;

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
  boat_state.Path? _currentPath;
  final Color _colorOk = const Color.fromARGB(255, 0, 0, 0);
  final Color _colorWarn = const Color.fromARGB(255, 255, 129, 10);
  final Color _colorError = const Color.fromARGB(255, 255, 0, 0);
  Color _menuIconColor = const Color.fromARGB(255, 0, 0, 0);
  final Color _connectionColorOK = const Color.fromARGB(255, 0, 255, 0);
  Color _connectionIconColor = const Color.fromARGB(255, 0, 0, 0);
  int _lastConnectionTime = DateTime.now().millisecondsSinceEpoch - 3000;
  var _nodeStates = <boat_state.NodeInfo>[];
  var _polylines = <Polyline>[];
  DateTime _lastTime = DateTime.now();
  double _currentBallastValue = 0.0;

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

  final _formKey = GlobalKey<FormState>();
  String _field1 = '';
  String _field2 = '';

  bool _showPathButton = false;
  LatLng? _mapPressLatLng;
  TapPosition? _mapPressPosition;

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

    // _servers["172.29.201.10"] =
    //     DropdownMenuEntry(value: "172.29.201.10", label: "sailbot-nano");
    // _servers["172.29.81.241"] =
    //     DropdownMenuEntry(value: "172.29.81.241", label: "sailbot-orangepi");
    //_servers["0.0.0.0"] = DropdownMenuEntry(value: "0.0.0.0", label: "ERR");
    github_helper.getServers().then((servers) {
      setState(() {
        //update servers list
        for (github_helper.Server server in servers) {
          dev.log("Server: ${server.name}, ${server.address}", name: "github");
          _servers[server.address] =
              DropdownMenuEntry(value: server.address, label: server.name);
        }
        _selectedValue = _servers.values.first.value;
      });
    });
    //gRPC client
    networkComms = NetworkComms(receiveBoatState, "172.29.81.241");
    //dev.log("Created comms object", name: "network");("172.29.81.241");

    //controller
    if (io.Platform.isLinux) {
      GamepadControllerLinux(_updateControlAngles);
    } else if (io.Platform.isWindows) {
      GamepadControllerWindows(_updateControlAngles);
    }

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
    networkComms?.setRudderAngle(angle);
  }

  _updateTrimtabAngle(double angle) {
    networkComms?.setTrimtabAngle(angle);
  }

  void _updateControlAngles(int rudderStickValue, int trimTabStickValue) {
    if (rudderStickValue.abs() < 10000) {
      rudderStickValue = 0;
    }
    if (trimTabStickValue.abs() < 10000) {
      trimTabStickValue = 0;
    }
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

  receiveBoatState(boat_state.BoatState boatState) {
    setState(() {
      DateTime currentTime = DateTime.now();
      _lastConnectionTime = currentTime.millisecondsSinceEpoch;
      _heading = boatState.currentHeading;
      _speed = boatState.speedKnots;
      _trueWind = boatState.trueWind.direction;
      _apparentWind = boatState.apparentWind.direction;
      _nodeStates = boatState.nodeStates;
      _boatLatLng = LatLng(boatState.latitude, boatState.longitude);
      _currentPath = boatState.currentPath;
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

      var previousBoatPoints = boatState.previousPositions.points;
      var previousPoints = <LatLng>[];
      if (previousBoatPoints.isNotEmpty) {
        previousPoints.add(_boatLatLng);
      }
      for (var point in previousBoatPoints) {
        previousPoints.add(LatLng(point.latitude, point.longitude));
      }
      _polylines.add(Polyline(
        points: previousPoints,
        strokeWidth: 4,
        color: Colors.black.withOpacity(0.6),
        isDotted: true,
      ));

      bool allOk = true;
      bool error = false;
      bool warn = false;
      for (boat_state.NodeInfo status in boatState.nodeStates) {
        if (status.status == boat_state.NodeStatus.NODE_STATUS_ERROR) {
          allOk = false;
          error = true;
        }
        if (status.status == boat_state.NodeStatus.NODE_STATUS_WARN) {
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

  _restartNode(String val) {
    networkComms?.restartNode(val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildDrawer(context, MapPage.route, _nodeStates, _restartNode),
      endDrawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text('Drawer Header'),
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
                Expanded(
                    child: MaterialButton(
                  onPressed: () {
                    _showFormDialog(context);
                  },
                  color: Colors.blue,
                  textColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: const CircleBorder(),
                  child: const Icon(
                    Icons.add,
                    size: 24,
                  ),
                )),
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
                    ),
                  ),
                  onTap: (tapPosition, latlng) {
                    setState(() {
                      _showPathButton = false;
                      _mapPressPosition = null;
                      _mapPressLatLng = null;
                    });
                  },
                  onSecondaryTap: (tapPosition, point) {
                    setState(() {
                      _showPathButton = true;
                      _mapPressPosition = tapPosition;
                      _mapPressLatLng = point;
                    });
                  },
                  onLongPress: (tapPosition, latlng) {
                    setState(() {
                      _showPathButton = true;
                      _mapPressPosition = tapPosition;
                      _mapPressLatLng = latlng;
                    });
                  },
                  onPositionChanged: (position, hasGesture) {
                    setState(() {
                      _showPathButton = false;
                      _mapPressPosition = null;
                      _mapPressLatLng = null;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'dev.wpi.sailbot.sailbot_telemetry',
                  ),
                  PolylineLayer(polylines: _polylines),
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
            offset: Offset(displayWidth(context) / 4.5, -40),
            child: Align(
              alignment: Alignment.bottomLeft,
              // centerPoint:
              //     Offset(displayWidth(context) / 2, displayHeight(context) / 2),
              child: _rudderControlWidget,
            ),
          ),
          Transform.translate(
            offset: Offset(-displayWidth(context) / 4.5, -40),
            child: Align(
              alignment: Alignment.bottomRight,
              // centerPoint:
              //     Offset(displayWidth(context) / 2, displayHeight(context) / 2),
              child: _trimTabControlWidget,
            ),
          ),
          if (_showPathButton)
            Positioned(
              top: _mapPressPosition?.global.dy,
              left: _mapPressPosition?.global.dx,
              child: FloatingActionButton(
                onPressed: () {
                  // Handle button press
                  //_currentPath = boat_state.Path();
                  var tappedPoint = boat_state.Point();
                  tappedPoint.latitude = _mapPressLatLng?.latitude ?? 0;
                  tappedPoint.longitude = _mapPressLatLng?.longitude ?? 0;
                  //_currentPath?.points.add(tappedPoint);

                  var newPath = boat_state.Path();
                  newPath.points.addAll(_currentPath?.points ?? List.empty());
                  newPath.points.add(tappedPoint);
                  newPath.latitudeDirection =
                      _currentPath?.latitudeDirection ?? "";
                  newPath.longitudeDirection =
                      _currentPath?.longitudeDirection ?? "";

                  networkComms?.setPath(newPath);
                  setState(
                    () {
                      _showPathButton = false; // Hide the button after pressing
                    },
                  );
                },
                child: Icon(Icons.add),
              ),
            ),
          if (_showPathButton)
            Positioned(
              top: (_mapPressPosition?.global.dy)! - 5.0,
              left: (_mapPressPosition?.global.dx)! - 5.0,
              child: Container(
                width: 10, // Circle diameter
                height: 10, // Circle diameter
                decoration: BoxDecoration(
                  color: Colors.red, // Circle color
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(0, displayHeight(context) / 2 - 140),
            child: Align(
              //alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 20,
                width: 200,
                child: Slider(
                  inactiveColor: const Color.fromARGB(255, 100, 100, 100),
                  activeColor: const Color.fromARGB(255, 0, 100, 255),
                  value: _currentBallastValue,
                  max: 1.0,
                  min: -1.0,
                  onChanged: (value) {
                    setState(() {
                      _currentBallastValue = value;
                      networkComms?.setBallastPosition(value);
                    });
                  },
                ),
              ),
            ),
          )
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

  void _showFormDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Server'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min, // Make dialog content compact
              children: [
                TextFormField(
                  onChanged: (value) => _field1 = value,
                  decoration: InputDecoration(labelText: 'IP Address'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter some text';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  onChanged: (value) => _field2 = value,
                  decoration: InputDecoration(labelText: 'Nickname'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter some text';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Submit'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _servers[_field1] =
                      DropdownMenuEntry(value: _field1, label: _field2);
                  // Handle the form submission logic here
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Field 1: $_field1, Field 2: $_field2'),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

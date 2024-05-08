import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart'
    as boat_state;
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/video.pb.dart'
    as video_pb;
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pbenum.dart';
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
import 'package:sailbot_telemetry_flutter/widgets/icons.dart';

double radians(double degrees) => degrees * (pi / 180.0);
double degrees(double radians) => radians * (180.0 / pi);
double calculateBearing(LatLng start, LatLng end) {
  var startLat = radians(start.latitude);
  var startLng = radians(start.longitude);
  var endLat = radians(end.latitude);
  var endLng = radians(end.longitude);

  var dLong = endLng - startLng;

  var dPhi = log(tan(endLat / 2.0 + pi / 4.0) / tan(startLat / 2.0 + pi / 4.0));
  if (dLong.abs() > pi) {
    if (dLong > 0.0) {
      dLong = -(2.0 * pi - dLong);
    } else {
      dLong = (2.0 * pi + dLong);
    }
  }

  return (degrees(atan2(dLong, dPhi)) + 360.0) % 360.0;
}

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
  LatLng _boatLatLng = const LatLng(51.5, -0.09);
  boat_state.Path? _currentPath;
  boat_state.WaypointPath? _currentWaypoints;
  LatLng _currentTargetPosition = const LatLng(51.5, -0.09);
  final Color _colorOk = const Color.fromARGB(255, 0, 0, 0);
  final Color _colorWarn = const Color.fromARGB(255, 255, 129, 10);
  final Color _colorError = const Color.fromARGB(255, 255, 0, 0);
  Color _menuIconColor = const Color.fromARGB(255, 0, 0, 0);
  final Color _connectionColorOK = const Color.fromARGB(255, 0, 255, 0);
  Color _connectionIconColor = const Color.fromARGB(255, 0, 0, 0);
  int _lastConnectionTime = DateTime.now().millisecondsSinceEpoch - 3000;
  var _nodeStates = <boat_state.NodeInfo>[];
  final _polylines = <Polyline>[];
  final _markers = <Marker>[];
  DateTime _lastTime = DateTime.now();
  double _currentBallastValue = 0.0;
  String _currentTrimState = "MANUAL";
  bool _showCameraFeed = false;
  MemoryImage? _currentImageProvider;
  Image? _currentImageWidget;
  late ImageStreamListener _imageStreamListener;

  String _selectedCameraSource = 'COLOR';
  final Map<String, String> _cameraSourceDropdownOptions = {
    'COLOR': 'Color',
    'MASK': 'Mask',
  };

  NetworkComms? networkComms;
  //Socket? _socket;
  final int retryDuration = 1; // duration in seconds
  final int connectionTimeout = 1; // timeout duration in seconds

  bool _autoBallast = false;
  var lastBallastTime = DateTime.now().millisecondsSinceEpoch;

  String _selectedAutonomousMode = 'NONE';
  final Map<String, String> _autonomousModeDropdownOptions = {
    'NONE': 'Manual',
    'BALLAST': 'Auto ballast',
    'TRIMTAB': 'Auto Trimtab',
    'FULL': 'Full auto',
  };
  bool _justChangedToManual = false;

  //callback for updating video feed when images load
  void _updateImageWidget() {
    if (mounted) {
      setState(() {
        _currentImageWidget = Image(
          image: _currentImageProvider!,
          fit: BoxFit.cover,
          key: UniqueKey(),
        );
      });
    }
  }

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

  final Map<String, DropdownMenuEntry<String>> _servers = HashMap();
  String? _selectedValue;

  final _formKey = GlobalKey<FormState>();
  String _field1 = '';
  String _field2 = '';

  bool _showPathButton = false;
  LatLng? _mapPressLatLng;
  TapPosition? _mapPressPosition;

  ImageProvider? mapImageProvider;
  LatLngBounds? mapBounds;

  @override
  void initState() {
    super.initState();

    //init image stream listener here, since _updateImageWidget won't be accessible in construction
    _imageStreamListener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        _updateImageWidget();
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        dev.log('Error loading image: $exception');
      },
    );
    //control widgets
    _trimTabControlWidget = CircleDragWidget(
      width: 150,
      height: 75,
      lineLength: 60,
      radius: 7,
      resetOnRelease: false,
      isInteractive: true,
      callback: _updateTrimtabAngle,
      key: trimTabKey,
    );
    _rudderControlWidget = CircleDragWidget(
      width: 150,
      height: 75,
      lineLength: 60,
      radius: 7,
      resetOnRelease: true,
      isInteractive: true,
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
        if (_selectedValue != null) {
          _resetComms(_selectedValue!);
        }
        dev.log("Created comms object with address: $_selectedValue",
            name: "network");
      });
    });
    //gRPC client
    networkComms = NetworkComms(
        receiveBoatState, receiveMap, receiveVideoFrame, _selectedValue);

    //controller
    if (io.Platform.isLinux) {
      GamepadControllerLinux(_updateControlAngles);
    } else if (io.Platform.isWindows) {
      GamepadControllerWindows(_updateControlAngles);
    }

    Timer.periodic(const Duration(seconds: 1), (timer) {
      _connectionStatusCallback();
    });
  }

  void _clearPath() {
    var newWaypoints = boat_state.WaypointPath();
    networkComms?.setWaypoints(newWaypoints);
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

  void _connectionStatusCallback() {
    setState(() {
      DateTime currentTime = DateTime.now();
      if (currentTime.millisecondsSinceEpoch - _lastConnectionTime > 3000) {
        _connectionIconColor = _colorError;
        dev.log("Resetting comms");
        networkComms?.terminate();
        _currentImageWidget = null;
        networkComms = NetworkComms(receiveBoatState, receiveMap,
            receiveVideoFrame, networkComms!.server!);
        if (_showCameraFeed) {
          networkComms?.startVideoStreaming();
        }
      } else {
        _connectionIconColor = _connectionColorOK;
      }
    });
  }

  receiveMap(boat_state.MapResponse map) {
    //dev.log("Callback triggered!");
    setState(() {
      mapBounds = LatLngBounds(
        LatLng(map.north, map.west),
        LatLng(map.south, map.east),
      );
      Uint8List lst = Uint8List.fromList(map.imageData);
      mapImageProvider = MemoryImage(lst);
    });
  }

  Future<void> receiveVideoFrame(video_pb.VideoFrame frame) async {
    final newImageProvider = MemoryImage(Uint8List.fromList(frame.data));
    final ImageStream imageStream =
        newImageProvider.resolve(ImageConfiguration.empty);
    imageStream.addListener(_imageStreamListener);
    _currentImageProvider = newImageProvider;
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
      _currentWaypoints = boatState.currentWaypoints;

      if (_selectedAutonomousMode == 'FULL' || _justChangedToManual) {
        _justChangedToManual = false;
        _rudderControlWidget
            ?.setAngle(boatState.rudderPosition * (pi / 180) * -1);
      }
      _currentTargetPosition = LatLng(boatState.currentTargetPoint.latitude,
          boatState.currentTargetPoint.longitude);
      switch (boatState.currentTrimState) {
        case TrimState.TRIM_STATE_MIN_LIFT:
          _currentTrimState = "MIN_LIFT";
          break;
        case TrimState.TRIM_STATE_MAX_LIFT_PORT:
          _currentTrimState = "MAX_LIFT_PORT";
          break;
        case TrimState.TRIM_STATE_MAX_LIFT_STARBOARD:
          _currentTrimState = "MAX_LIFT_STBD";
          break;
        case TrimState.TRIM_STATE_MAX_DRAG_PORT:
          _currentTrimState = "MAX_DRAG_PORT";
          break;
        case TrimState.TRIM_STATE_MAX_DRAG_STARBOARD:
          _currentTrimState = "MAX_DRAG_STBD";
          break;
        case TrimState.TRIM_STATE_MANUAL:
          _currentTrimState = "MANUAL";
          break;
      }
      //waypoints
      _markers.clear();
      var boatWaypoints = boatState.currentWaypoints.waypoints;
      for (var waypoint in boatWaypoints) {
        _markers.add(Marker(
            point: LatLng(waypoint.point.latitude, waypoint.point.longitude),
            child: const Icon(Icons.star_border_purple500_rounded)));
      }
      for (var buoy in boatState.buoyPositions) {
        _markers.add(Marker(
            point: LatLng(buoy.latitude, buoy.longitude),
            height: 20,
            width: 20,
            child: Image.asset("assets/buoy.png")));
      }
      _markers.add(Marker(
          point: _boatLatLng,
          height: 60,
          width: 60,
          child: Transform.rotate(
              angle: _heading * pi / 180,
              child: Image.asset("assets/arrow.png"))));
      _markers.add(Marker(
          point: _boatLatLng,
          height: 30,
          width: 30,
          child: Image.asset("assets/boat.png")));
      _markers.add(Marker(
          point: _currentTargetPosition,
          height: 20,
          width: 20,
          child: const Icon(
            Icons.star_border_purple500_rounded,
            color: Colors.red,
          )));
      if (boatState.hasTargetHeading) {
        _markers.add(Marker(
            point: _boatLatLng,
            height: 80,
            width: 80,
            child: Transform.rotate(
                angle: boatState.targetHeading_35 * pi / 180,
                child: Transform.scale(
                    scaleY: 2,
                    scaleX: 1.5,
                    child: const Icon(
                      Icons.arrow_upward,
                      color: Colors.purple,
                    )))));
      }
      //path lines
      _polylines.clear();
      var boatPoints = boatState.currentPath.points;
      dev.log("Path has ${boatPoints.length} points");
      var points = <LatLng>[];
      // if (boatPoints.isNotEmpty) {
      //   points.add(_boatLatLng);
      // }
      for (int i = 0; i < boatPoints.length; i++) {
        var point = boatPoints[i];
        var latlng = LatLng(point.latitude, point.longitude);
        points.add(latlng);

        double bearing = 0;
        if (i < boatPoints.length - 1) {
          var nextPoint = boatPoints[i + 1];
          var nextLatLng = LatLng(nextPoint.latitude, nextPoint.longitude);
          bearing = calculateBearing(latlng, nextLatLng);
        } else if (i != 0) {
          var prevPoint = boatPoints[i - 1];
          var nextLatLng = LatLng(prevPoint.latitude, prevPoint.longitude);
          bearing = calculateBearing(latlng, nextLatLng) + 180;
        }
        var marker = Marker(
          point: latlng,
          child: Transform.rotate(
            angle: radians(bearing),
            child: const Icon(Icons.arrow_circle_up_rounded),
          ),
        );
        _markers.add(marker);
      }
      _polylines.add(Polyline(
        points: points,
        strokeWidth: 4,
        color: Colors.blue.withOpacity(0.6),
        borderStrokeWidth: 6,
        borderColor: Colors.red.withOpacity(0.4),
      ));
      if (boatState.hasCurrentPathSegment) {
        dev.log("Has current path segment!");
        LatLng start = LatLng(boatState.currentPathSegment_33.start.latitude,
            boatState.currentPathSegment_33.start.longitude);
        LatLng end = LatLng(boatState.currentPathSegment_33.end.latitude,
            boatState.currentPathSegment_33.end.longitude);
        _polylines.add(Polyline(
            points: [start, end], strokeWidth: 5, color: Colors.green));
      }

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

  _addWaypoint(WaypointType type) {
    var tappedPoint = boat_state.Waypoint();
    tappedPoint.type = type;
    var point = boat_state.Point();
    point.latitude = _mapPressLatLng?.latitude ?? 0;
    point.longitude = _mapPressLatLng?.longitude ?? 0;
    tappedPoint.point = point;

    networkComms?.addWaypoint(tappedPoint);
    setState(
      () {
        _showPathButton = false; // Hide the button after pressing
      },
    );
  }

  _restartNode(String val) {
    networkComms?.restartNode(val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildDrawer(
          context, MapPage.route, _nodeStates, _restartNode, _clearPath),
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
            ListTile(
              title: const Text("VF forward magnitude"),
              subtitle: TextField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: "1.0"),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                ],
                onSubmitted: ((String value) {
                  networkComms?.setVFForwardMagnitude(double.parse(value));
                }),
              ),
            ),
          ],
        ),
      ),
      key: _scaffoldState,
      body: Stack(
        children: [
          Flex(direction: Axis.horizontal, children: <Widget>[
            Flexible(
              child: _showCameraFeed
                  ? Container(
                      width: MediaQuery.of(context).size.width,
                      child: RepaintBoundary(child: _currentImageWidget) ??
                          const Center(child: CircularProgressIndicator()))
                  : FlutterMap(
                      options: MapOptions(
                        initialCenter: const LatLng(42.277062, -71.756299),
                        initialZoom: 15,
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
                          userAgentPackageName:
                              'dev.wpi.sailbot.sailbot_telemetry',
                        ),
                        if (mapBounds != null && mapImageProvider != null)
                          OverlayImageLayer(overlayImages: [
                            OverlayImage(
                                imageProvider: mapImageProvider!,
                                bounds: mapBounds!)
                          ]),
                        PolylineLayer(polylines: _polylines),
                        MarkerLayer(markers: _markers),
                      ],
                    ),
            ),
          ]),
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
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  const Text("Trim state:"),
                  Text(
                    _currentTrimState,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ]),
                const Divider(
                  color: Colors.grey,
                  thickness: 1,
                  indent: 5,
                  endIndent: 5,
                ),
                Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  const Text("Auto mode:"),
                  DropdownButton<String>(
                    value: _selectedAutonomousMode,
                    dropdownColor: const Color.fromARGB(255, 255, 255, 255),
                    onChanged: (String? newValue) {
                      setState(() {
                        if (_selectedAutonomousMode != 'NONE') {
                          _justChangedToManual = true;
                        }
                        _selectedAutonomousMode = newValue!;
                      });
                      setAutonomousMode(_selectedAutonomousMode);
                    },
                    items: _autonomousModeDropdownOptions.entries
                        .map<DropdownMenuItem<String>>(
                            (MapEntry<String, String> entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                  ),
                ]),
              ]),
            ),
          ),
          Align(
              alignment: Alignment.centerRight,
              child: MaterialButton(
                child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: const Icon(Icons.camera_alt_rounded)),
                onPressed: () {
                  setState(() {
                    _showCameraFeed = !_showCameraFeed;
                    if (_showCameraFeed) {
                      networkComms?.startVideoStreaming();
                    } else {
                      networkComms?.cancelVideoStreaming();
                    }
                  });
                },
              )),
          Align(
              alignment: Alignment.centerRight,
              // centerPoint:
              //     Offset(displayWidth(context), displayHeight(context) / 2),
              //width: min(displayWidth(context) / 3, 200),
              child: _showCameraFeed
                  ? Container(
                      transform: Matrix4.translationValues(0, -50.0, 0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCameraSource,
                        dropdownColor: const Color.fromARGB(255, 255, 255, 255),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCameraSource = newValue!;
                          });
                          setCameraSource(_selectedCameraSource);
                        },
                        items: _cameraSourceDropdownOptions.entries
                            .map<DropdownMenuItem<String>>(
                                (MapEntry<String, String> entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                      ))
                  : const Text("")),
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
              icon: const Icon(Icons.settings),
              color: _connectionIconColor,
              onPressed: () {
                _scaffoldState.currentState?.openEndDrawer();
              },
            ),
          ),
          Transform.translate(
            offset: Offset(displayWidth(context) / 9, -40),
            child: Align(
              alignment: Alignment.bottomLeft,
              // centerPoint:
              //     Offset(displayWidth(context) / 2, displayHeight(context) / 2),
              child: _rudderControlWidget,
            ),
          ),
          Transform.translate(
            offset: Offset(-displayWidth(context) / 9, -40),
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
              child: Column(children: <Widget>[
                FloatingActionButton(
                  onPressed: () {
                    _addWaypoint(WaypointType.WAYPOINT_TYPE_INTERSECT);
                  },
                  child: const Icon(Icons.add),
                ),
                FloatingActionButton(
                  onPressed: () {
                    _addWaypoint(WaypointType.WAYPOINT_TYPE_CIRCLE_RIGHT);
                  },
                  child: Transform(
                      transform: Matrix4.rotationX(pi),
                      alignment: Alignment.center,
                      child: const Icon(MyFlutterApp.u_turn)),
                ),
                FloatingActionButton(
                  onPressed: () {
                    _addWaypoint(WaypointType.WAYPOINT_TYPE_CIRCLE_LEFT);
                  },
                  child: Transform(
                      transform: Matrix4.rotationZ(pi),
                      alignment: Alignment.center,
                      child: const Icon(MyFlutterApp.u_turn)),
                )
              ]),
            ),
          if (_showPathButton)
            Positioned(
              top: (_mapPressPosition?.global.dy)! - 5.0,
              left: (_mapPressPosition?.global.dx)! - 5.0,
              child: Container(
                width: 10, // Circle diameter
                height: 10, // Circle diameter
                decoration: const BoxDecoration(
                  color: Colors.red, // Circle color
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(0, displayHeight(context) / 2 - 180),
            child: Align(
              //alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 40,
                width: 300,
                child: Slider(
                  inactiveColor: const Color.fromARGB(255, 100, 100, 100),
                  activeColor: const Color.fromARGB(255, 0, 100, 255),
                  value: _currentBallastValue,
                  max: 1.0,
                  min: -1.0,
                  onChanged: _autoBallast
                      ? null
                      : (value) {
                          setState(() {
                            _currentBallastValue = value;
                            var time = DateTime.now().millisecondsSinceEpoch;
                            if (time - lastBallastTime > 50) {
                              networkComms?.setBallastPosition(value);
                              lastBallastTime = time;
                            }
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

  void setCameraSource(String selectedSource) {
    networkComms?.setCameraSource(selectedSource);
  }

  void setAutonomousMode(String selectedMode) {
    // Perform different actions based on the selected option
    if (selectedMode == 'NONE') {
      dev.log('Manual control');
      networkComms?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_NONE);

      _trimTabControlWidget?.setInteractive(true);
      _rudderControlWidget?.setInteractive(true);
      _autoBallast = false;
    } else if (selectedMode == 'BALLAST') {
      dev.log('Auto ballast');
      networkComms?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_BALLAST);

      _trimTabControlWidget?.setInteractive(true);
      _rudderControlWidget?.setInteractive(true);
      _autoBallast = true;
    } else if (selectedMode == 'TRIMTAB') {
      dev.log('auto trimtab');
      networkComms?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_TRIMTAB);
      _trimTabControlWidget?.setInteractive(false);
      _autoBallast = true;
      _rudderControlWidget?.setInteractive(true);
    } else if (selectedMode == 'FULL') {
      dev.log('Full auto');
      networkComms?.setAutonomousMode(AutonomousMode.AUTONOMOUS_MODE_FULL);

      _trimTabControlWidget?.setInteractive(false);
      _rudderControlWidget?.setInteractive(false);
      _autoBallast = true;
    }
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
          title: const Text('Add Server'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min, // Make dialog content compact
              children: [
                TextFormField(
                  onChanged: (value) => _field1 = value,
                  decoration: const InputDecoration(labelText: 'IP Address'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter some text';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  onChanged: (value) => _field2 = value,
                  decoration: const InputDecoration(labelText: 'Nickname'),
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
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Submit'),
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

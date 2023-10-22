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
import 'dart:io';
import 'package:sailbot_telemetry_flutter/utils/utils.dart';
import 'package:sailbot_telemetry_flutter/widgets/draggable_circle.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';

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
  var _nodeStates = <NodeInfo>[];

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

  @override
  void initState() {
    super.initState();
    _initComms();
  }

  void _initComms() async {
    networkComms = NetworkComms(receiveBoatState);
    dev.log("Created comms object", name: "network");
  }

  _updateRudderAngle(double angle) {
    networkComms?.updateRudderAngle(angle);
  }

  receiveBoatState(BoatState boatState) {
    setState(() {
      _heading = boatState.currentHeading;
      _speed = boatState.speedKnots;
      _trueWind = boatState.trueWind.direction;
      _apparentWind = boatState.apparentWind.direction;
      _nodeStates = boatState.nodeStates;
      _boatLatLng = LatLng(boatState.latitude, boatState.longitude);
      bool allOk = true;
      bool error = false;
      bool warn = false;
      for (NodeInfo status in boatState.nodeStates) {
        if (status.status == NodeStatus.ERROR) {
          allOk = false;
          error = true;
        }
        if (status.status == NodeStatus.WARN) {
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
      //dev.log("Apparent wind: $_apparentWind");
    });
  }
  // _setupSocket() async {
  //   String hostname =
  //       'sailbot-orangepi.netbird.cloud'; // Replace this with your hostname
  //   List<InternetAddress> addresses = await InternetAddress.lookup(hostname);
  //   InternetAddress address = addresses[0];
  //   const port = 1111;
  //   dev.log("about to connect", name: 'socket');
  //   try {
  //     _socket = await Socket.connect(address, port,
  //         timeout: Duration(seconds: connectionTimeout));
  //     dev.log(
  //         'Connected to: ${_socket?.remoteAddress.address}:${_socket?.remotePort}',
  //         name: 'socket');
  //     _socket?.listen((List<int> event) {
  //       //final data = String.fromCharCodes(event);
  //       //dev.log("Received data!");
  //       try {
  //         BoatState boatState = BoatState.fromBuffer(event);
  //         setState(() {
  //           _heading = boatState.currentHeading;
  //           _speed = boatState.speedKnots;
  //           _trueWind = boatState.trueWind.direction;
  //           _apparentWind = boatState.apparentWind.direction;
  //           _nodeStates = boatState.nodeStates;
  //           _boatLatLng = LatLng(boatState.latitude, boatState.longitude);
  //           bool allOk = true;
  //           bool error = false;
  //           bool warn = false;
  //           for (NodeInfo status in boatState.nodeStates) {
  //             if (status.status == NodeStatus.ERROR) {
  //               allOk = false;
  //               error = true;
  //             }
  //             if (status.status == NodeStatus.WARN) {
  //               allOk = false;
  //               warn = true;
  //             }
  //           }
  //           if (allOk) {
  //             _menuIconColor = _colorOk;
  //           } else {
  //             if (warn) _menuIconColor = _colorWarn;
  //             if (error) _menuIconColor = _colorError;
  //           }

  //           //dev.log("Apparent wind: $_apparentWind");
  //         });
  //         // dev.log('Received: ${boatState.speedKnots}', name: 'protobuf');
  //       } catch (e) {
  //         dev.log("Error decoding protobuf!");
  //         _handleSocketError();
  //       }
  //       // setState(() {
  //       //   //_data = data;
  //       // });
  //     }, onError: (error) {
  //       dev.log("Socket error: $error", name: "socket");
  //     }, onDone: () {
  //       dev.log("Socket closed! did Sailbot crash? :(", name: "socket");
  //       _handleSocketError();
  //     });
  //   } catch (e) {
  //     dev.log('having trouble connecting to sailbot...: $e', name: 'socket');
  //     _handleSocketError();
  //   }
  // }

  // void _handleSocketError() {
  //   // Close the socket (if not already closed)
  //   if (_socket != null) {
  //     _socket!.close();
  //     _socket = null;
  //   }

  //   // Wait for a duration and then try to reconnect
  //   Future.delayed(Duration(seconds: retryDuration), _setupSocket);
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Map'),
      //   toolbarHeight: min(displayHeight(context) / 16, 40),
      // ),
      drawer: buildDrawer(context, MapPage.route, _nodeStates),
      key: _scaffoldState,
      body: Padding(
        padding: const EdgeInsets.all(0),
        child: Stack(
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
                    // MarkerLayer(markers: [
                    //   Marker(
                    //       point: _boatLatLng,
                    //       height: 60,
                    //       width: 60,
                    //       child: Transform.rotate(
                    //           angle: _heading * pi / 180,
                    //           child: Image.file(File("assets/arrow.png")))),
                    //   Marker(
                    //       point: _boatLatLng,
                    //       height: 30,
                    //       width: 30,
                    //       child: Image.file(File("assets/boat.png")))
                    // ])
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
                          child: _buildCompassGauge(
                              _heading, _compassAnnotations)),
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
                      child:
                          _buildCompassGauge(_trueWind, _compassAnnotations)),
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
            AlignPositioned(
              alignment: Alignment.center,
              centerPoint:
                  Offset(displayWidth(context) / 2, displayHeight(context) / 2),
              child: CircleDragWidget(
                  width: 200,
                  height: 100,
                  radius: 10,
                  callback: _updateRudderAngle),
            ),
          ],
        ),
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

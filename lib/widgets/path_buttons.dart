import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_widget.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/widgets/icons.dart';
import 'dart:math';

class PathButtons extends ConsumerWidget {
  PathButtons({super.key});

  late WidgetRef _ref;
  NetworkComms? _networkComms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _ref = ref;
    _networkComms = ref.watch(networkCommsProvider);

    final mapState = ref.watch(mapStateProvider);
    return mapState.showPathButton ? Positioned(
              top: mapState.mapPressPosition?.global.dy,
              left: mapState.mapPressPosition?.global.dx,
              child: Column(children: <Widget>[
                FloatingActionButton(
                  onPressed: () {
                    _addWaypoint(WaypointType.WAYPOINT_TYPE_INTERSECT, mapState.mapPressLatLng);
                  },
                  child: const Icon(Icons.add),
                ),
                FloatingActionButton(
                  onPressed: () {
                    _addWaypoint(WaypointType.WAYPOINT_TYPE_CIRCLE_RIGHT, mapState.mapPressLatLng);
                  },
                  child: Transform(
                      transform: Matrix4.rotationX(pi),
                      alignment: Alignment.center,
                      child: const Icon(MyFlutterApp.u_turn)),
                ),
                FloatingActionButton(
                  onPressed: () {
                    _addWaypoint(WaypointType.WAYPOINT_TYPE_CIRCLE_LEFT, mapState.mapPressLatLng);
                  },
                  child: Transform(
                      transform: Matrix4.rotationZ(pi),
                      alignment: Alignment.center,
                      child: const Icon(MyFlutterApp.u_turn)),
                )
              ]),
            ) : const Text("");
  }
  _addWaypoint(WaypointType type, LatLng? pos) {
    var tappedPoint = Waypoint();
    tappedPoint.type = type;
    var point = Point();
    point.latitude = pos?.latitude ?? 0;
    point.longitude = pos?.longitude ?? 0;
    tappedPoint.point = point;

    _networkComms?.addWaypoint(tappedPoint);
    _ref.read(mapStateProvider.notifier).resetTapDetails();
  }
}
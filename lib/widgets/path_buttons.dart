import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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

    TextEditingController latController = TextEditingController();
    TextEditingController lonController = TextEditingController();
    var pressLat = mapState.mapPressLatLng?.latitude;
    var pressLong = mapState.mapPressLatLng?.longitude;
    LatLng latlng = LatLng(pressLat ?? 0, pressLong ?? 0);

    if (!mapState.showPathButton) {
      return const SizedBox.shrink();
    }

    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;

    // Initial position
    double top = mapState.mapPressPosition?.global.dy ?? 0;
    double left = mapState.mapPressPosition?.global.dx ?? 0;

    double widgetHeight = 180; // Approximate height of the widget
    double widgetWidth = 183; // Approximate width of the widget

    // Adjust position if the widget goes off-screen
    if (top + widgetHeight > screenSize.height) {
      top = screenSize.height - widgetHeight;
    }
    if (left + widgetWidth > screenSize.width) {
      left = screenSize.width - widgetWidth;
    }

    return Positioned(
      top: top,
      left: left,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(20))), 
        child: Row(children: <Widget>[
          Column(children: <Widget>[
            SizedBox(
              width: 120,
              child: ListTile(
                title: const Text("Latitude"),
                subtitle: TextField(
                  controller: latController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(hintText: pressLat.toString()),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  onEditingComplete: () {
                    latlng = LatLng(
                        double.parse(latController.text), latlng.longitude);
                  },
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: ListTile(
                title: const Text("Longitude"),
                subtitle: TextField(
                  controller: lonController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(hintText: pressLong.toString()),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  onEditingComplete: () {
                    latlng = LatLng(
                        latlng.latitude, double.parse(lonController.text));
                  },
                ),
              ),
            ),
          ]),
          Column(children: <Widget>[
            FloatingActionButton(
              onPressed: () {
                _addWaypoint(WaypointType.WAYPOINT_TYPE_INTERSECT, latlng);
              },
              child: Transform(
                transform: Matrix4.rotationZ(pi / 4),
                alignment: Alignment.center,
                child: const Icon(Icons.add),
              ),
            ),
            FloatingActionButton(
              onPressed: () {
                _addWaypoint(WaypointType.WAYPOINT_TYPE_CIRCLE_RIGHT, latlng);
              },
              child: Transform(
                transform: Matrix4.rotationX(pi),
                alignment: Alignment.center,
                child: const Icon(MyFlutterApp.u_turn),
              ),
            ),
            FloatingActionButton(
              onPressed: () {
                _addWaypoint(WaypointType.WAYPOINT_TYPE_CIRCLE_LEFT, latlng);
              },
              child: Transform(
                transform: Matrix4.rotationZ(pi),
                alignment: Alignment.center,
                child: const Icon(MyFlutterApp.u_turn),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _addWaypoint(WaypointType type, LatLng? pos) {
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

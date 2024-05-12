import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/utils/utils.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:developer' as dev;
import 'dart:typed_data';

class MapState {
  final bool showPathButton;
  final TapPosition?
      mapPressPosition; // Define TapPosition according to your data type
  final LatLng? mapPressLatLng;

  MapState(
      {this.showPathButton = false,
      this.mapPressPosition,
      this.mapPressLatLng});

  MapState copyWith({
    bool? showPathButton,
    TapPosition? mapPressPosition,
    LatLng? mapPressLatLng,
  }) {
    return MapState(
      showPathButton: showPathButton ?? this.showPathButton,
      mapPressPosition: mapPressPosition ?? this.mapPressPosition,
      mapPressLatLng: mapPressLatLng ?? this.mapPressLatLng,
    );
  }
}

class MapStateNotifier extends StateNotifier<MapState> {
  MapStateNotifier() : super(MapState());

  void setPathButtonVisibility(bool visible) {
    state = state.copyWith(showPathButton: visible);
  }

  void setTapDetails(TapPosition position, LatLng latLng) {
    state = state.copyWith(
        showPathButton: true,
        mapPressPosition: position,
        mapPressLatLng: latLng);
  }

  void resetTapDetails() {
    state = state.copyWith(
        showPathButton: false, mapPressPosition: null, mapPressLatLng: null);
  }
}

final mapStateProvider =
    StateNotifierProvider<MapStateNotifier, MapState>((ref) {
  return MapStateNotifier();
});

class MapView extends ConsumerWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watchers
    final map = ref.watch(mapImageProvider);
    final boatState = ref.watch(boatStateProvider);

    final mapBounds = LatLngBounds(
      LatLng(map.north, map.west),
      LatLng(map.south, map.east),
    );
    Uint8List lst = Uint8List.fromList(map.imageData);
    final mapImage = MemoryImage(lst);

    final polylines = <Polyline>[];
    final markers = <Marker>[];
    final heading = boatState.currentHeading;
    final boatLatLng = LatLng(boatState.latitude, boatState.longitude);
    final currentTargetPosition = LatLng(boatState.currentTargetPoint.latitude,
        boatState.currentTargetPoint.longitude);
    // Set up map markers
    //waypoints
    var boatWaypoints = boatState.currentWaypoints.waypoints;
    for (var waypoint in boatWaypoints) {
      markers.add(Marker(
          point: LatLng(waypoint.point.latitude, waypoint.point.longitude),
          child: const Icon(Icons.star_border_purple500_rounded)));
    }
    for (var buoy in boatState.buoyPositions) {
      markers.add(Marker(
          point: LatLng(buoy.latitude, buoy.longitude),
          height: 20,
          width: 20,
          child: Image.asset("assets/buoy.png")));
    }
    markers.add(Marker(
        point: boatLatLng,
        height: 60,
        width: 60,
        child: Transform.rotate(
            angle: heading * pi / 180,
            child: Image.asset("assets/arrow.png"))));
    markers.add(Marker(
        point: boatLatLng,
        height: 30,
        width: 30,
        child: Image.asset("assets/boat.png")));
    markers.add(Marker(
        point: currentTargetPosition,
        height: 20,
        width: 20,
        child: const Icon(
          Icons.star_border_purple500_rounded,
          color: Colors.red,
        )));
    if (boatState.hasTargetHeading) {
      markers.add(Marker(
          point: boatLatLng,
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
      markers.add(marker);
    }
    polylines.add(Polyline(
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
      polylines.add(
          Polyline(points: [start, end], strokeWidth: 5, color: Colors.green));
    }

    var previousBoatPoints = boatState.previousPositions.points;
    var previousPoints = <LatLng>[];
    if (previousBoatPoints.isNotEmpty) {
      previousPoints.add(boatLatLng);
    }
    for (var point in previousBoatPoints) {
      previousPoints.add(LatLng(point.latitude, point.longitude));
    }
    polylines.add(Polyline(
      points: previousPoints,
      strokeWidth: 4,
      color: Colors.black.withOpacity(0.6),
      isDotted: true,
    ));

    return FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(42.277062, -71.756299),
        initialZoom: 15,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all - InteractiveFlag.rotate,
          cursorKeyboardRotationOptions: CursorKeyboardRotationOptions(
            isKeyTrigger: (key) => false,
          ),
        ),
        onTap: (_, __) {
          ref.read(mapStateProvider.notifier).resetTapDetails();
        },
        onSecondaryTap: (tapPosition, point) {
          ref.read(mapStateProvider.notifier).setTapDetails(tapPosition, point);
        },
        onLongPress: (tapPosition, latlng) {
          ref
              .read(mapStateProvider.notifier)
              .setTapDetails(tapPosition, latlng);
        },
        onPositionChanged: (_, __) {
          ref.read(mapStateProvider.notifier).resetTapDetails();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'dev.wpi.sailbot.sailbot_telemetry',
        ),
        OverlayImageLayer(overlayImages: [
          OverlayImage(imageProvider: mapImage, bounds: mapBounds!)
        ]),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

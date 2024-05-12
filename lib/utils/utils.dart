import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

Size displaySize(BuildContext context) {
  return MediaQuery.of(context).size;
}

double displayHeight(BuildContext context) {
  double height = displaySize(context).height;
  //dev.log("height is: $height", name: 'testing');
  return height;
}

double displayWidth(BuildContext context) {
  double width = displaySize(context).width;
  //dev.log("width is: $width", name: 'testing');
  return width;
}

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
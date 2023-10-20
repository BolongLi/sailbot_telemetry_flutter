import 'package:flutter/material.dart';

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

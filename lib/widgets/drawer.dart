import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/pages/map.dart';

Widget _buildMenuItem(
  BuildContext context,
  Widget title,
  String routeName,
  String currentRoute, {
  Widget? icon,
}) {
  final isSelected = routeName == currentRoute;

  return ListTile(
    title: title,
    leading: icon,
    selected: isSelected,
    onTap: () {
      if (isSelected) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, routeName);
      }
    },
  );
}

Drawer buildDrawer(BuildContext context, String currentRoute) {
  return Drawer(
    child: ListView(
      children: <Widget>[
        _buildMenuItem(
          context,
          const Text('Map'),
          MapPage.route,
          currentRoute,
          icon: const Icon(Icons.home),
        ),
      ],
    ),
  );
}

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

Drawer buildDrawer(BuildContext context, String currentRoute,
    List<String> nodeNames, List<bool> nodeStates) {
  var nodeStatusWidgets = <Widget>[];
  int i = 0;
  for (var nodeName in nodeNames) {
    Widget newWidget = DecoratedBox(
      decoration:
          BoxDecoration(color: nodeStates[i] ? Colors.green : Colors.red),
      child: Text(nodeName),
    );
    nodeStatusWidgets.add(newWidget);
    i += 1;
  }

  return Drawer(
    child: Row(
      children: <Widget>[
        Expanded(
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
        ),
        Expanded(
            child: ListView(
          children: nodeStatusWidgets,
        )),
      ],
    ),
  );
}

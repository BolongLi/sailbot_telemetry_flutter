import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/pages/map.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/utils/utils.dart';

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

Drawer buildDrawer(
    BuildContext context, String currentRoute, List<NodeInfo> nodeStates) {
  var nodeStatusWidgets = <Widget>[];
  const Color colorOk = Color.fromARGB(255, 0, 255, 0);
  const Color colorWarn = Color.fromARGB(255, 255, 129, 10);
  const Color colorError = Color.fromARGB(255, 255, 0, 0);
  for (NodeInfo nodeInfo in nodeStates) {
    Color color = colorOk;
    if (nodeInfo.status == NodeStatus.WARN) {
      color = colorWarn;
    }
    if (nodeInfo.status == NodeStatus.ERROR) {
      color = colorError;
    }
    Widget newWidget = DecoratedBox(
      decoration:
          BoxDecoration(color: color, border: Border.all(color: Colors.black)),
      child: SizedBox(
        height: displayHeight(context) / 20,
        child: Text(
          nodeInfo.name,
          textAlign: TextAlign.center,
        ),
      ),
    );
    nodeStatusWidgets.add(newWidget);
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

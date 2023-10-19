import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sailbot_telemetry_flutter/widgets/drawer.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  static const String route = '/polyline';

  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telemetry')),
      drawer: buildDrawer(context, MapPage.route),
      body: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Flexible(
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(51.5, -0.09),
                  initialZoom: 5,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'dev.wpi.sailbot.sailbot_telemetry',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

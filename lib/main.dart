import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/pages/map.dart';
import 'package:flutter/services.dart';

void main() async {
  // final receivePort = ReceivePort();
  // log("about to launch isolate");
  // Isolate isolate = await Isolate.spawn(SailbotComms.sailbotComms, receivePort);
  // log("listening to data");
  // receivePort.listen((data) {
  //   // Handle the data/message sent from the secondary isolate
  //   // For example, you can update your app's state here
  // });
  // log("launching app");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  final MapPage page = const MapPage();
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    return MaterialApp(
      title: 'SailbotTelemetry',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: page,
    );
  }
}

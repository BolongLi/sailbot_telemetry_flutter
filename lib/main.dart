import 'package:flutter/material.dart';
import 'package:sailbot_telemetry_flutter/pages/map.dart';
import 'package:flutter/services.dart';
import 'package:sailbot_telemetry_flutter/isolates/sailbot_comms.dart';
import 'dart:isolate';
import 'dart:async';
import 'dart:developer';

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
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.bottom]);
    return MaterialApp(
      title: 'SailbotTelemetry',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MapPage(),
    );
  }
}

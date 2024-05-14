import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_widget.dart';
import 'package:sailbot_telemetry_flutter/widgets/camera_widget.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';



class CVSettings extends ConsumerStatefulWidget {
  const CVSettings({super.key});

  @override
  _CVSettingsState createState() => _CVSettingsState();
  
}

class _CVSettingsState extends ConsumerState<CVSettings>{
  CVParameters _currentParameters = CVParameters();

  @override
  void initState() {
    super.initState();
  }
  @override
  void dispose() {
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    CVParameters? cvParameters = ref.watch(cvParametersProvider);
    if(cvParameters != null){
      _currentParameters = cvParameters;
    }
    final networkComms = ref.watch(networkCommsProvider);
    return Column(children: <Widget>[
      Row(children: [SizedBox(width: 25, child: Text("UH: ", textAlign: TextAlign.center)),Slider(
        activeColor: const Color.fromARGB(255, 0, 100, 255),
        value: _currentParameters.upperH,
        max: 1,
        min: 0,
        onChanged: (value) {
          networkComms?.setCVParameters(_currentParameters);
          setState(() {
            _currentParameters.upperH = value;
          });
        }
      ), Text((_currentParameters.upperH*255).toInt().toString())],),
      Row(children: [SizedBox(width: 25, child: Text("US: ", textAlign: TextAlign.center)),Slider(
        activeColor: const Color.fromARGB(255, 0, 100, 255),
        value: _currentParameters.upperS,
        max: 1,
        min: 0,
        onChanged: (value) {
          networkComms?.setCVParameters(_currentParameters);
          setState(() {
            _currentParameters.upperS = value;
          });
        }
      ), Text((_currentParameters.upperS*255).toInt().toString())],),
      Row(children: [SizedBox(width: 25, child: Text("UV: ", textAlign: TextAlign.center)),Slider(
        activeColor: const Color.fromARGB(255, 0, 100, 255),
        value: _currentParameters.upperV,
        max: 1,
        min: 0,
        onChanged: (value) {
          networkComms?.setCVParameters(_currentParameters);
          setState(() {
            _currentParameters.upperV = value;
          });
        }
      ), Text((_currentParameters.upperV*255).toInt().toString())],),
      Row(children: [SizedBox(width: 25, child: Text("LH: ", textAlign: TextAlign.center)),Slider(
        activeColor: const Color.fromARGB(255, 0, 100, 255),
        value: _currentParameters.lowerH,
        max: 1,
        min: 0,
        onChanged: (value) {
          networkComms?.setCVParameters(_currentParameters);
          setState(() {
            _currentParameters.lowerH = value;
          });
        }
      ), Text((_currentParameters.lowerH*255).toInt().toString())],),
      Row(children: [SizedBox(width: 25, child: Text("LS: ", textAlign: TextAlign.center)),Slider(
        activeColor: const Color.fromARGB(255, 0, 100, 255),
        value: _currentParameters.lowerS,
        max: 1,
        min: 0,
        onChanged: (value) {
          networkComms?.setCVParameters(_currentParameters);
          setState(() {
            _currentParameters.lowerS = value;
          });
        }
      ), Text((_currentParameters.lowerS*255).toInt().toString())],),
      Row(children: [SizedBox(width: 25, child: Text("LV: ", textAlign: TextAlign.center)),Slider(
        activeColor: const Color.fromARGB(255, 0, 100, 255),
        value: _currentParameters.lowerV,
        max: 1,
        min: 0,
        onChanged: (value) {
          networkComms?.setCVParameters(_currentParameters);
          setState(() {
            _currentParameters.lowerV = value;
          });
        }
      ), Text((_currentParameters.lowerV*255).toInt().toString())],),
      Row(children: [SizedBox(width: 30, child: Text("CIR: ", textAlign: TextAlign.center)),Slider(
        activeColor: const Color.fromARGB(255, 0, 100, 255),
        value: _currentParameters.circularityThreshold,
        max: 1,
        min: 0,
        onChanged: (value) {
          networkComms?.setCVParameters(_currentParameters);
          setState(() {
            _currentParameters.circularityThreshold = value;
          });
        }
      ), Text((_currentParameters.circularityThreshold).toStringAsFixed(3))],),
    ],);
  }
}
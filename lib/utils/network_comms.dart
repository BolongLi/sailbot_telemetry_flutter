import 'dart:async';
import 'package:grpc/grpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/control.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/connect.pbgrpc.dart';
import 'dart:developer' as dev; //log() conflicts with math

class NetworkComms {
  ExecuteControlCommandServiceClient? _controlCommandStub;
  SendBoatStateServiceClient? _sendBoatStateStub;
  Function _boatStateCallback;

  NetworkComms(this._boatStateCallback) {
    _createClient();
    dev.log('created client to boat');
    Timer.periodic(const Duration(seconds: 1), (Timer t) {
      _sendBoatStateStub?.sendBoatState(BoatStateRequest()).then((boatState) {
        _boatStateCallback(boatState);
      });
    });
  }

  Future<void> _createClient() async {
    dev.log("about to create channel", name: 'network');
    final channel = ClientChannel(
      '172.29.81.241',
      port: 50051,
      options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
          keepAlive: ClientKeepAliveOptions(
              pingInterval: Duration(seconds: 1),
              timeout: Duration(seconds: 2))),
    );
    channel.onConnectionStateChanged.listen((connectionState) {
      switch (connectionState) {
        case ConnectionState.idle:
          dev.log("Connection is idle.", name: 'network');
          break;
        case ConnectionState.connecting:
          dev.log("Connecting to server...", name: 'network');
          break;
        case ConnectionState.ready:
          dev.log("Connected to server.", name: 'network');
          break;
        case ConnectionState.transientFailure:
          dev.log("Connection lost. Attempting to reconnect...",
              name: 'network');
          break;
        case ConnectionState.shutdown:
          dev.log("Connection is shutting down or shut down.", name: 'network');
          break;
      }
    });
    dev.log("created channel", name: 'network');
    _controlCommandStub = ExecuteControlCommandServiceClient(channel);
    _sendBoatStateStub = SendBoatStateServiceClient(channel);
  }

  _sendControlCommand(double value, ControlType type) {
    ControlCommand command = ControlCommand();
    command.controlType = type;
    command.controlValue = value;
    _controlCommandStub?.executeControlCommand(command).then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Control command returned with response: $status",
          name: 'network');
    });
  }

  updateRudderAngle(double angle) {
    _sendControlCommand(angle, ControlType.CONTROL_TYPE_RUDDER);
  }

  updateTrimtabAngle(double angle) {
    _sendControlCommand(angle, ControlType.CONTROL_TYPE_TRIM_TAB);
  }
}

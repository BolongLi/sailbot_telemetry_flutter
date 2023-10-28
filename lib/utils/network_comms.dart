import 'dart:async';
import 'package:grpc/grpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/control.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/node_restart.pbgrpc.dart';
import 'dart:developer' as dev; //log() conflicts with math

class NetworkComms {
  String? _server;
  ExecuteRudderCommandServiceClient? _rudderCommandServiceClient;
  ExecuteTrimTabCommandServiceClient? _trimTabCommandServiceClient;
  ExecuteBallastCommandServiceClient? _ballastCommandServiceClient;
  ExecuteAutonomousModeCommandServiceClient?
      _autonomousModeCommandServiceClient;
  ExecuteSetPathCommandServiceClient? _setPathCommandServiceClient;
  SendBoatStateServiceClient? _sendBoatStateStub;
  RestartNodeServiceClient? _restartNodeStub;
  Function _boatStateCallback;
  Timer? _timer;

  NetworkComms(this._boatStateCallback, this._server) {
    _createClient();
    dev.log('created client to boat');
  }

  void reconnect(String server) {
    _server = server;
    _createClient();
  }

  Future<void> _createClient() async {
    _timer?.cancel();
    dev.log("about to create channel", name: 'network');
    if (_server == null) {
      dev.log("Something went wrong, server address is null", name: 'network');
      return;
    }
    var channel = ClientChannel(
      _server ?? "?",
      port: 50051,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        keepAlive: ClientKeepAliveOptions(
            pingInterval: Duration(seconds: 1), timeout: Duration(seconds: 2)),
      ),
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
    _rudderCommandServiceClient = ExecuteRudderCommandServiceClient(channel);
    _trimTabCommandServiceClient = ExecuteTrimTabCommandServiceClient(channel);
    _ballastCommandServiceClient = ExecuteBallastCommandServiceClient(channel);
    _autonomousModeCommandServiceClient =
        ExecuteAutonomousModeCommandServiceClient(channel);
    _setPathCommandServiceClient = ExecuteSetPathCommandServiceClient(channel);
    _sendBoatStateStub = SendBoatStateServiceClient(channel);
    _restartNodeStub = RestartNodeServiceClient(channel);
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      _sendBoatStateStub?.sendBoatState(BoatStateRequest()).then((boatState) {
        _boatStateCallback(boatState);
      });
    });
  }

  restartNode(String node) {
    RestartNodeRequest request = RestartNodeRequest();
    request.nodeName = node;
    _restartNodeStub?.restartNode(request).then((response) {
      dev.log("Restart node: ${response.success ? "success" : "fail"}",
          name: "network");
    });
  }

  setRudderAngle(double angle) {
    RudderCommand command = RudderCommand();
    command.rudderControlValue = angle;
    dev.log("sending rudder command", name: "network");
    _rudderCommandServiceClient?.executeRudderCommand(command).then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Rudder control command returned with response: $status",
          name: 'network');
    });
  }

  setTrimtabAngle(double angle) {
    TrimTabCommand command = TrimTabCommand();
    command.trimtabControlValue = angle;
    _trimTabCommandServiceClient
        ?.executeTrimTabCommand(command)
        .then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Trimtab control command returned with response: $status",
          name: 'network');
    });
  }

  setBallastPosition(
      double
          position /* positions from -1.0 (full left) to 1.0 (full right) */) {
    BallastCommand command = BallastCommand();
    command.ballastControlValue = position;
    _ballastCommandServiceClient
        ?.executeBallastCommand(command)
        .then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Ballast control command returned with response: $status",
          name: 'network');
    });
  }

  setPath(
    Path newPath,
  ) {
    SetPathCommand command = SetPathCommand();
    command.newPath = newPath;
    _setPathCommandServiceClient
        ?.executeSetPathCommand(command)
        .then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Override path control command returned with response: $status",
          name: 'network');
    });
  }

  setAutonomousMode(AutonomousMode mode) {
    AutonomousModeCommand command = AutonomousModeCommand();
    command.autonomousMode = mode;
    _autonomousModeCommandServiceClient
        ?.executeAutonomousModeCommand(command)
        .then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Autonomous mode control command returned with response: $status",
          name: 'network');
    });
  }
}

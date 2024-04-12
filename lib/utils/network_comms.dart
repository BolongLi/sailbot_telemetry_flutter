import 'dart:async';
import 'package:grpc/grpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/control.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/node_restart.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/video.pbgrpc.dart';
import 'dart:developer' as dev; //log() conflicts with math

class NetworkComms {
  String? _server;
  ExecuteRudderCommandServiceClient? _rudderCommandServiceClient;
  ExecuteTrimTabCommandServiceClient? _trimTabCommandServiceClient;
  ExecuteBallastCommandServiceClient? _ballastCommandServiceClient;
  ExecuteAutonomousModeCommandServiceClient?
      _autonomousModeCommandServiceClient;
  ExecuteSetWaypointsCommandServiceClient? _setWaypointsCommandServiceClient;
  ExecuteAddWaypointCommandServiceClient? _addWaypointCommandServiceClient;
  SendBoatStateServiceClient? _sendBoatStateStub;
  StreamBoatStateServiceClient? _streamBoatStateStub;
  GetMapServiceClient? _getMapStub;
  RestartNodeServiceClient? _restartNodeStub;
  VideoStreamerClient? _videoStreamerStub;
  StreamSubscription<VideoFrame>? _streamSubscription;
  final Function _boatStateCallback;
  final Function _mapCallback;
  final Function _videoFrameCallback;
  Timer? _timer;

  NetworkComms(this._boatStateCallback, this._mapCallback,
      this._videoFrameCallback, this._server) {
    _createClient();
    dev.log('created client to boat');
  }

  void reconnect(String server) {
    _server = server;
    _createClient();
  }

  void _initializeBoatStateStream() {
    final call = _streamBoatStateStub!.streamBoatState(BoatStateRequest());
    call.listen((BoatState response) {
      _boatStateCallback(response);
    }, onError: (e) {
      dev.log("Error: $e", name: "network");
      // Do not attempt to reconnect both here and in onDone, it creates exponential callbacks
    }, onDone: () {
      // Stream closed, possibly due to server shutdown or network issue
      dev.log("Stream closed", name: "network");
      // Attempt to reconnect after a delay
      Future.delayed(const Duration(seconds: 1), () {
        if (_server != null) {
          reconnect(_server!);
        }
        _initializeBoatStateStream();
      });
    });
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
          MapRequest request = MapRequest();
          _getMapStub?.getMap(request).then((response) {
            dev.log(
                "got map response: ${response.north}, ${response.south}, ${response.east}, ${response.west}");
            if (response.north != 0 && response.south != 0) {
              _mapCallback(response);
            }
          });

          _initializeBoatStateStream();
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
    _setWaypointsCommandServiceClient =
        ExecuteSetWaypointsCommandServiceClient(channel);
    _addWaypointCommandServiceClient =
        ExecuteAddWaypointCommandServiceClient(channel);
    _sendBoatStateStub = SendBoatStateServiceClient(channel);
    _streamBoatStateStub = StreamBoatStateServiceClient(channel);
    _getMapStub = GetMapServiceClient(channel);
    _restartNodeStub = RestartNodeServiceClient(channel);
    _videoStreamerStub = VideoStreamerClient(channel);

    //dummy call to force gRPC to open the connection immediately
    _sendBoatStateStub?.sendBoatState(BoatStateRequest()).then((boatState) {});
  }

  startVideoStreaming() {
    final call = _videoStreamerStub!.streamVideo(VideoRequest());
    _streamSubscription = call.listen((VideoFrame response) {
      _videoFrameCallback(response);
    }, onError: (e) {
      dev.log("Error: $e", name: "network");
    }, onDone: () {
      // Stream closed, possibly due to server shutdown or network issue
      dev.log("Video stream closed", name: "network");
    });
  }

  void cancelVideoStreaming() {
    if (_streamSubscription != null) {
      _streamSubscription!.cancel();
      _streamSubscription = null;
      dev.log("Video stream canceled", name: "network");
    }
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

  setWaypoints(
    WaypointPath newWaypoints,
  ) {
    SetWaypointsCommand command = SetWaypointsCommand();
    command.newWaypoints = newWaypoints;
    _setWaypointsCommandServiceClient
        ?.executeSetWaypointsCommand(command)
        .then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log(
          "Override waypoints control command returned with response: $status",
          name: 'network');
    });
  }

  addWaypoint(
    Waypoint newWaypoint,
  ) {
    AddWaypointCommand command = AddWaypointCommand();
    command.newWaypoint = newWaypoint;
    _addWaypointCommandServiceClient
        ?.executeAddWaypointCommand(command)
        .then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Add waypoint control command returned with response: $status",
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

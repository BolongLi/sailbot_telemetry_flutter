import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:grpc/grpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/control.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/node_restart.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/video.pbgrpc.dart';
import 'dart:developer' as dev; //log() conflicts with math

import 'package:sailbot_telemetry_flutter/utils/github_helper.dart' as gh;

final boatStateProvider = StateNotifierProvider<BoatStateNotifier, BoatState>((ref) {
  return BoatStateNotifier();
});

final mapImageProvider = StateNotifierProvider<MapImageNotifier, MapResponse>((ref) {
  return MapImageNotifier();
});

final videoFrameProvider = StateNotifierProvider<VideoFrameNotifier, VideoFrame>((ref) {
  return VideoFrameNotifier();
});

class BoatStateNotifier extends StateNotifier<BoatState> {
  BoatStateNotifier() : super(BoatState());

  void update(BoatState newState) {
    state = newState;
  }
}

class MapImageNotifier extends StateNotifier<MapResponse> {
  MapImageNotifier() : super(MapResponse());

  void update(MapResponse newImage) {
    state = newImage;
  }
}

class VideoFrameNotifier extends StateNotifier<VideoFrame> {
  VideoFrameNotifier() : super(VideoFrame());

  void update(VideoFrame newFrame) {
    state = newFrame;
  }
}

final selectedServerProvider = StateProvider<gh.Server?>((ref) => null);

final networkCommsProvider = Provider<NetworkComms?>((ref) {
  final selectedServer = ref.watch(selectedServerProvider);
  dev.log("Watching selectedServerProvider: ${selectedServer?.address}");
  if (selectedServer != null) {
    dev.log("Recreating NetworkComms with server: ${selectedServer.address}");
    return NetworkComms(selectedServer.address, ref);
  } else {
    dev.log("Selected server is null, returning null");
  }
  return null; // Return null until a server is selected
});

class NetworkComms {
  String? server;
  ExecuteRudderCommandServiceClient? _rudderCommandServiceClient;
  ExecuteTrimTabCommandServiceClient? _trimTabCommandServiceClient;
  ExecuteBallastCommandServiceClient? _ballastCommandServiceClient;
  ExecuteAutonomousModeCommandServiceClient?
      _autonomousModeCommandServiceClient;
  ExecuteSetWaypointsCommandServiceClient? _setWaypointsCommandServiceClient;
  ExecuteAddWaypointCommandServiceClient? _addWaypointCommandServiceClient;
  ExecuteSetVFForwardMagnitudeCommandServiceClient?
      _setVFForwardMagnitudeCommandServiceClient;
  ExecuteSetRudderKPCommandServiceClient? _setRudderKPCommandServiceClient;
  SendBoatStateServiceClient? _sendBoatStateStub;
  StreamBoatStateServiceClient? _streamBoatStateStub;
  GetMapServiceClient? _getMapStub;
  RestartNodeServiceClient? _restartNodeStub;
  VideoStreamerClient? _videoStreamerStub;
  StreamSubscription<VideoFrame>? _streamSubscription;
  String _currentCameraSource = 'COLOR';

  Timer? _timer;

  ClientChannel? channel;

  final ProviderRef ref;

  NetworkComms(this.server, this.ref) {
    _createClient();
    dev.log('created client to boat');
  }

  void reconnect(String server) {
    this.server = server;
    _createClient();
  }

  void _initializeBoatStateStream() {
    final call = _streamBoatStateStub!.streamBoatState(BoatStateRequest());
    call.listen((BoatState response) {
      ref.read(boatStateProvider.notifier).update(response);
    }, onError: (e) {
      dev.log("Error: $e", name: "network");
      // Do not attempt to reconnect both here and in onDone, it creates exponential callbacks
    }, onDone: () {
      // Stream closed, possibly due to server shutdown or network issue
      dev.log("Stream closed", name: "network");
    });
  }

  Future<void> _createClient() async {
    _timer?.cancel();
    dev.log("about to create channel", name: 'network');
    if (server == null) {
      dev.log("Something went wrong, server address is null", name: 'network');
      return;
    }
    channel = ClientChannel(
      server ?? "?",
      port: 50051,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        keepAlive: ClientKeepAliveOptions(
            pingInterval: Duration(seconds: 1), timeout: Duration(seconds: 2)),
      ),
    );
    channel?.onConnectionStateChanged.listen((connectionState) {
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
              ref.read(mapImageProvider.notifier).update(response);
            }
          });

          _initializeBoatStateStream();
          break;
        case ConnectionState.transientFailure:
          dev.log("Connection lost, transient failure", name: 'network');
          break;
        case ConnectionState.shutdown:
          dev.log("Connection is shutting down or shut down.", name: 'network');
          break;
      }
    });
    dev.log("created channel", name: 'network');
    _rudderCommandServiceClient = ExecuteRudderCommandServiceClient(channel!);
    _trimTabCommandServiceClient = ExecuteTrimTabCommandServiceClient(channel!);
    _ballastCommandServiceClient = ExecuteBallastCommandServiceClient(channel!);
    _autonomousModeCommandServiceClient =
        ExecuteAutonomousModeCommandServiceClient(channel!);
    _setWaypointsCommandServiceClient =
        ExecuteSetWaypointsCommandServiceClient(channel!);
    _addWaypointCommandServiceClient =
        ExecuteAddWaypointCommandServiceClient(channel!);
    _setVFForwardMagnitudeCommandServiceClient =
        ExecuteSetVFForwardMagnitudeCommandServiceClient(channel!);
    _setRudderKPCommandServiceClient =
        ExecuteSetRudderKPCommandServiceClient(channel!);
    _sendBoatStateStub = SendBoatStateServiceClient(channel!);
    _streamBoatStateStub = StreamBoatStateServiceClient(channel!);
    _getMapStub = GetMapServiceClient(channel!);
    _restartNodeStub = RestartNodeServiceClient(channel!);
    _videoStreamerStub = VideoStreamerClient(channel!);

    //dummy call to force gRPC to open the connection immediately
    _sendBoatStateStub?.sendBoatState(BoatStateRequest()).then((boatState) {});
  }

  terminate() {
    channel?.terminate();
  }

  startVideoStreaming() {
    VideoRequest req = VideoRequest();
    req.videoSource = _currentCameraSource;
    final call = _videoStreamerStub!.streamVideo(req);
    _streamSubscription = call.listen((VideoFrame response) {
      ref.read(videoFrameProvider.notifier).update(response);
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

  setCameraSource(String source) {
    cancelVideoStreaming();
    _currentCameraSource = source;
    startVideoStreaming();
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

  setVFForwardMagnitude(double magnitude) {
    SetVFForwardMagnitudeCommand command = SetVFForwardMagnitudeCommand();
    command.magnitude = magnitude;
    _setVFForwardMagnitudeCommandServiceClient
        ?.executeSetVFForwardMagnitudeCommand(command)
        .then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log(
          "Set VF forward magnitude command returned with response: $status",
          name: 'network');
    });
  }

  setRudderKP(double kp) {
    SetRudderKPCommand command = SetRudderKPCommand();
    command.kp = kp;
    _setRudderKPCommandServiceClient
        ?.executeSetRudderKPCommand(command)
        .then((response) {
      ControlExecutionStatus status = response.executionStatus;
      dev.log("Set rudder KP command returned with response: $status",
          name: 'network');
    });
  }
}

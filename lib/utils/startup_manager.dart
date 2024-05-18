import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:grpc/grpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/startup_messages/dart/startup.pb.dart';
import 'package:sailbot_telemetry_flutter/submodules/startup_messages/dart/startup.pbgrpc.dart';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart' as gh;

class LogNotifier extends StateNotifier<List<String>> {
  LogNotifier() : super([]);

  void addLog(String log) {
    state = [...state, log];
  }

  void clearLogs() {
    state = [];
  }
}

final logProvider = StateNotifierProvider<LogNotifier, List<String>>((ref) {
  return LogNotifier();
});


final ros2ControlProvider = StateNotifierProvider<ROS2ControlNotifier, String?>((ref) {
  return ROS2ControlNotifier();
});

class ROS2ControlNotifier extends StateNotifier<String?> {
  ROS2ControlNotifier() : super(null);

  void update(String? newState) {
    state = newState;
  }
}

String lastServerAddress = "dummy1";

final ros2NetworkCommsProvider = StateNotifierProvider<ROS2NetworkCommsNotifier, ROS2NetworkComms?>((ref) {
  final notifier = ROS2NetworkCommsNotifier(ref);

  ref.listen(selectedServerProvider, (__, selectedServer) { 
    if (selectedServer != null && selectedServer.address != lastServerAddress && selectedServer.address != "") {
        dev.log("Changing server: ${selectedServer.address}, $lastServerAddress");
    notifier.initializeClient(selectedServer.address);
    notifier.streamLogs();
    lastServerAddress = selectedServer.address;
  }
  });
  return notifier;
});

class ROS2NetworkCommsNotifier extends StateNotifier<ROS2NetworkComms?> {
  ROS2NetworkCommsNotifier(this.ref) : super(null);

  final StateNotifierProviderRef ref;
  Timer? _retryTimer;
  static const int _retryInterval = 2; // Retry interval in seconds

  void initializeClient(String serverAddress) {
    _createClient(serverAddress);
  }

  void streamLogs(){
    state?.streamLogs();
  }

  Future<void> _createClient(String serverAddress) async {
    try {
      final client = ROS2NetworkComms(serverAddress, ref);
      state = client;
      dev.log('Connected to ROS2 server at $serverAddress');
    } catch (e) {
      dev.log('Failed to connect to ROS2 server at $serverAddress. Retrying in $_retryInterval seconds...');
    }
  }

  @override
  void dispose() {
    state?.dispose();
    super.dispose();
  }
}

class ROS2NetworkComms {
  String serverAddress;
  ClientChannel? channel;
  ROS2ControlClient? ros2ControlClient;
  StreamSubscription<LogMessage>? _logSubscription;
  Timer? _retryTimer;

  final StateNotifierProviderRef ref;

  ROS2NetworkComms(this.serverAddress, this.ref) {
    _createClient();
    dev.log('Created ROS2 client');
  }

  Future<void> _createClient() async {
    try {
      channel = ClientChannel(
        serverAddress,
        port: 50052,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
          keepAlive: ClientKeepAliveOptions(
              pingInterval: Duration(seconds: 1), timeout: Duration(seconds: 2)),
        ),
      );

      channel?.onConnectionStateChanged.listen((connectionState) {
        switch (connectionState) {
          case ConnectionState.idle:
            dev.log("Connection is idle.", name: 'ros2_network');
            break;
          case ConnectionState.connecting:
            dev.log("Connecting to server...", name: 'ros2_network');
            break;
          case ConnectionState.ready:
            dev.log("Connected to server.", name: 'ros2_network');
            break;
          case ConnectionState.transientFailure:
            dev.log("Connection lost, transient failure", name: 'ros2_network');
            break;
          case ConnectionState.shutdown:
            dev.log("Connection is shutting down or shut down.", name: 'ros2_network');
            break;
        }
      }, onError: (error) {
        dev.log('Connection error: $error', name: 'ros2_network');
      });

      ros2ControlClient = ROS2ControlClient(channel!);
      dev.log("Created ROS2 Control Client", name: 'ros2_network');
    } catch (e) {
      dev.log("Could not create channel: $e", name: 'ros2_network');
      rethrow;
    }
  }

  Future<void> startLaunch(String launchFile) async {
    final request = LaunchRequest()..launchFile = launchFile;
    try {
      final response = await ros2ControlClient!.start(request);
      ref.read(ros2ControlProvider.notifier).update(response.message);
      dev.log("Start launch response: ${response.message}", name: 'ros2_network');
    } catch (e) {
      dev.log("Failed to start launch: $e", name: 'ros2_network');
    }
  }

  Future<void> stopLaunch() async {
    try {
      final response = await ros2ControlClient!.stop(Empty());
      ref.read(ros2ControlProvider.notifier).update(response.message);
      dev.log("Stop launch response: ${response.message}", name: 'ros2_network');
    } catch (e) {
      dev.log("Failed to stop launch: $e", name: 'ros2_network');
    }
  }

  void streamLogs() {
    final call = ros2ControlClient!.streamLogs(Empty());
    _logSubscription = call.listen((LogMessage log) {
      ref.read(logProvider.notifier).addLog(log.log);
      dev.log(log.log, name: 'ros2_network_logs');
    }, onError: (e) {
      dev.log("Error streaming logs: $e", name: 'ros2_network');
      _retryTimer = Timer(const Duration(seconds: 1), () {
        streamLogs();
        _retryTimer?.cancel();
      });
    }, onDone: () {
      dev.log("Log stream closed", name: 'ros2_network');
    });
  }

  void cancelLogStream() {
    _logSubscription?.cancel();
    _logSubscription = null;
    _retryTimer?.cancel();
    dev.log("Log stream canceled", name: 'ros2_network');
  }

  void dispose() {
    cancelLogStream();
    channel?.shutdown();
    dev.log('ROS2NetworkComms resources have been disposed.');
  }
}
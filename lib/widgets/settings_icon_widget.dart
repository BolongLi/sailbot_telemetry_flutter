import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev;

import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pb.dart';
import 'package:sailbot_telemetry_flutter/utils/network_comms.dart';
import 'package:sailbot_telemetry_flutter/utils/github_helper.dart';
import 'package:sailbot_telemetry_flutter/widgets/map_camera_widget.dart';

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, Color>((ref) {
  return ConnectionNotifier(ref);
});

class ConnectionNotifier extends StateNotifier<Color> {
  Timer? _timer;
  int _lastConnectionTime = 0;
  final Color _colorError = Colors.red;
  final Color _connectionColorOK = Colors.green;
  NetworkComms? _networkComms;
  late StateNotifierProviderRef _ref;
  bool _cameraActive = false;
  Server? _selectedServer;

  ConnectionNotifier(StateNotifierProviderRef ref) : super(Colors.red) {
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _checkConnection());
    _ref = ref;

    // Listen to updates on the boatStateProvider
    ref.listen<BoatState>(boatStateProvider, (_, __) {
      updateLastConnectionTime();
    });
    ref.listen<NetworkComms?>(networkCommsProvider, (_, networkComms) {
      _networkComms = networkComms;
    });
    ref.listen<Server?>(selectedServerProvider, (_, selectedServer) {
      _selectedServer = selectedServer;
    });
    ref.listen<bool>(cameraToggleProvider, (_, cameraActive) {
      _cameraActive = cameraActive;
    });
  }

  void _checkConnection() {
    DateTime currentTime = DateTime.now();
    if (currentTime.millisecondsSinceEpoch - _lastConnectionTime > 3000) {
      state = _colorError;
      dev.log("Resetting comms");
      final lastServer = _ref.read(selectedServerProvider);
      _ref.read(selectedServerProvider.notifier).state = Server(name: "", address: "");
      _ref.read(selectedServerProvider.notifier).state = lastServer;
      if (_cameraActive) {
        _networkComms?.startVideoStreaming();
      }
    } else {
      state = _connectionColorOK;
    }
  }

  void updateLastConnectionTime() {
    _lastConnectionTime = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class SettingsIconWidget extends ConsumerWidget {
  const SettingsIconWidget(this._scaffoldState, {super.key});

  final GlobalKey<ScaffoldState> _scaffoldState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watchers
    final connectionIconColor = ref.watch(connectionProvider);

    return IconButton(
      icon: const Icon(Icons.settings),
      color: connectionIconColor,
      onPressed: () {
        _scaffoldState.currentState?.openEndDrawer();
      },
    );
  }
}

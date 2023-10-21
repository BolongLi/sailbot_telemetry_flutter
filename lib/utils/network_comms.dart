import 'package:grpc/grpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/boat_state.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/control.pbgrpc.dart';
import 'package:sailbot_telemetry_flutter/submodules/telemetry_messages/dart/connect.pbgrpc.dart';
import 'dart:developer' as dev; //log() conflicts with math

//client for ControlCommand, server for BoatState. Could separate.
class NetworkComms extends ReceiveBoatStateServiceBase {
  ExecuteControlCommandServiceClient? _controlCommandStub;
  ConnectToBoatServiceClient? _connectRequestStub;
  Function _boatStateCallback;

  NetworkComms(this._boatStateCallback) {
    final server = Server.create(services: [this]);
    _awaitServer(server);
    dev.log('Server listening on port ${server.port}...', name: 'network');
    _createClient();
    dev.log('created client to boat');
    _connectRequestStub?.connectToBoat(ConnectRequest()).then((response) {
      dev.log("Boat accepted connection");
    });
  }

  @override
  Future<Empty> receiveBoatState(ServiceCall call, BoatState state) async {
    _boatStateCallback(state);
    return Empty();
  }

  //constructor bodies cannot be async
  Future<void> _awaitServer(server) async {
    await server.serve(port: 50051);
  }

  Future<void> _createClient() async {
    dev.log("about to create channel", name: 'network');
    final channel = ClientChannel(
      'sailbot-orangepi.netbird.cloud',
      port: 50051,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    dev.log("created channel", name: 'network');
    _controlCommandStub = ExecuteControlCommandServiceClient(channel);
    _connectRequestStub = ConnectToBoatServiceClient(channel);
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
    // var bytes = command.writeToBuffer();
    // _socket?.write(bytes);
  }

  updateRudderAngle(double angle) {
    _sendControlCommand(angle, ControlType.CONTROL_TYPE_RUDDER);
  }
}

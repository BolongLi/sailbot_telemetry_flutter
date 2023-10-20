import 'dart:io';
import 'dart:developer';
import 'dart:isolate';

class SailbotComms {
  static Future<Socket> connectToSailbot() async {
    String hostname = 'example.com'; // Replace this with your hostname
    List<InternetAddress> addresses = await InternetAddress.lookup(hostname);
    InternetAddress address = addresses[0];
    const port = 1111;
    log("about to connect", name: 'socket');
    Socket socket = await Socket.connect(address, port,
        timeout: const Duration(seconds: 1));
    log('Connected to: ${socket.remoteAddress.address}:${socket.remotePort}',
        name: 'socket');
    return socket;
  }

  static void sailbotComms(ReceivePort receivePort) {
    connectToSailbot();
  }
}

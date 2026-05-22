import 'dart:io';
import 'package:hashlib/hashlib.dart';
import 'package:udp/udp.dart';
import 'netprot.dart';
import 'dart:typed_data';
import 'settings_service.dart';
import 'main.dart';

class UDPNetwork {
  // final socket = RawDatagramSocket.bind(udpAddr, port);
  var crc32 = CRC32(CRC32Params.ieee);

  void sendData(String deviceId, String dataId, Object data) async {
    // Get IP address and port from settings
    final udpAddr = settingsService.getIpAddress();
    final udpPort = settingsService.getPort();
    final devName = settingsService.getDeviceName();

    var multicastEndpoint = Endpoint.multicast(
      InternetAddress(udpAddr),
      port: Port(udpPort),
    );

    var sender = await UDP.bind(Endpoint.any());

    var topic = "LoggerButton" + "/" + devName + " " + dataId;
    var toSend = makeItem("TOPC", topic);

    await sender.send(toSend.asUint8List(), multicastEndpoint);
  }

  /**
 * Create a byte array to transmit. This is a bigger pain in the arse than 
 * I imagined it would be in dart !
 * Would have to do something a bit different for non string data, particularly 
 * with regard to getting the CRC. 
 */
  ByteBuffer makeItem(String name, String data) {
    var list = <int>[]; // this makes a list, rather than a set. big difference.
    list.addAll(name.codeUnits);

    // add the length of the data
    int n = data.length;
    Uint8List int32BigEndianBytes(int value) =>
        Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.big);
    var b3 = int32BigEndianBytes(n);
    list.addAll(b3);

    // add the data
    list.addAll(data.codeUnits);

    // generate and add a DRC32
    var h = crc32.code(data);
    var hBytes = int32BigEndianBytes(h);
    list.addAll(hBytes);

    // convert the integer list toa uint8 list for transmission.
    List<int> lll = List.from(list);
    Uint8List asuint8 = Uint8List.fromList(lll);

    return asuint8.buffer;
  }
}

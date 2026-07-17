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

  void sendData([String dataType = 'Default', String dataId = '', ByteBuffer? data]) async {
    // Get IP address and port from settings
    final udpAddr = settingsService.getIpAddress();
    final udpPort = settingsService.getPort();
    final devName = settingsService.getDeviceName();

    var multicastEndpoint = Endpoint.multicast(
      InternetAddress(udpAddr),
      port: Port(udpPort),
    );

    var sender = await UDP.bind(Endpoint.any());

    String topic;
    if (dataId.isNotEmpty) {
      topic = "$dataType/$devName $dataId";
    } else {
      topic = "$dataType/$devName";
    }
    var toSend = makeItem(topic, data);


    await sender.send(toSend.asUint8List(), multicastEndpoint);
  }

  /// Create a byte array to transmit. This is a bigger pain in the arse than 
  /// I imagined it would be in dart !
  /// Would have to do something a bit different for non string data, particularly 
  /// with regard to getting the CRC. 
  ByteBuffer makeItem(String data, [ByteBuffer? dataBuffer]) {
    var list = <int>[]; // this makes a list, rather than a set. big difference.
    list.addAll("TOPC".codeUnits);

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

    if (dataBuffer != null) {
      // add the length of the data
      int n = dataBuffer.lengthInBytes;
      var b3 = int32BigEndianBytes(n);
      list.addAll("DATA".codeUnits);
      list.addAll(b3);
    }

    // convert the integer list toa uint8 list for transmission.
    List<int> lll = List.from(list);
    Uint8List asuint8 = Uint8List.fromList(lll);
    if (dataBuffer != null) {
      // add the data buffer to the end of the list.
      asuint8 = Uint8List.fromList(asuint8 + dataBuffer.asUint8List());
      var h2 = crc32.code(dataBuffer.asUint8List().toString());
      var h2Bytes = int32BigEndianBytes(h2);
      asuint8 = Uint8List.fromList(asuint8 + h2Bytes);
    }

    return asuint8.buffer;
  }
}

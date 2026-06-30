/*
Example copied from https://github.com/shamblett/mqtt_client/blob/master/example/mqtt_server_client.dart
*/
import 'dart:ffi';
import 'dart:typed_data';

import 'settings_service.dart';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_buffers.dart';

class MQTTNetProt {
  // final client = MqttServerClient('test.mosquitto.org', 'uouypo888uop');
  // final client = MqttServerClient('192.168.1.173', 'uouyp89ouop');
  var client = null;

  var pongCount = 0; // Pong counter
  var pingCount = 0; // Ping counter

  SettingsService settingsService;

  MQTTNetProt(this.settingsService);

  Future<int> connect() async {
    /// A websocket URL must start with ws:// or wss:// or Dart will throw an exception, consult your websocket MQTT broker
    /// for details.
    /// To use websockets add the following lines -:
    /// client.useWebSocket = true;
    /// client.port = 80;  ( or whatever your WS port is)
    /// There is also an alternate websocket implementation for specialist use, see useAlternateWebSocketImplementation
    /// Note do not set the secure flag if you are using wss, the secure flags is for TCP sockets only.
    /// You can also supply your own websocket protocol list or disable this feature using the websocketProtocols
    /// setter, read the API docs for further details here, the vast majority of brokers will support the client default
    /// list so in most cases you can ignore this.
    /// 
    /// 
       print('MQTT client connecting to ${settingsService.getIpAddress()}:${settingsService.getPort()}');
   
    client = MqttServerClient(settingsService.getIpAddress(), settingsService.getDeviceName());

    /// Set logging on if needed, defaults to off
    client.logging(on: false);

    /// Set the correct MQTT protocol for mosquito
    client.setProtocolV31();

    /// If you intend to use a keep alive you must set it here otherwise keep alive will be disabled.
    client.keepAlivePeriod = 20;

    /// The connection timeout period can be set, the default is 5 seconds.
    /// if [client.socketTimeout] is set then this will take precedence and this setting will be
    /// disabled.
    client.connectTimeoutPeriod = 2000; // milliseconds

    client.port = 1883;

    /// The socket timeout period can be set, the minimum value is 1000ms.
    /// If set then this setting takes precedence and [client.connectionTimeoutPeriod] is disabled.
    /// client.socketTimeout = 2000; // milliseconds

    /// Add the unsolicited disconnection callback
    client.onDisconnected = onDisconnected;

    /// Add the successful connection callback
    client.onConnected = onConnected;

    /// Add a subscribed callback, there is also an unsubscribed callback if you need it.
    /// You can add these before connection or change them dynamically after connection if
    /// you wish. There is also an onSubscribeFail callback for failed subscriptions, these
    /// can fail either because you have tried to subscribe to an invalid topic or the broker
    /// rejects the subscribe request.
    client.onSubscribed = onSubscribed;

    /// Set a ping received callback if needed, called whenever a ping response(pong) is received
    /// from the broker. Can be used for health monitoring.
    client.pongCallback = pong;

    /// Set a ping sent callback if needed, called whenever a ping request(ping) is sent
    /// by the client. Can be used for latency calculations.
    client.pingCallback = ping;

    /// Create a connection message to use or use the default one. The default one sets the
    /// client identifier, any supplied username/password and clean session,
    /// an example of a specific one below.
    final connMess = MqttConnectMessage()
        .withClientIdentifier('Mqtt_MyClientUniqueId')
        .withWillTopic(
          'willtopic',
        ) // If you set this you must set a will message
        .withWillMessage('My Will message')
        .startClean() // Non persistent session for testing
        .withWillQos(MqttQos.atLeastOnce);
    // print('EXAMPLE::Mosquitto client connecting....');
    client.connectionMessage = connMess;

    /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
    /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
    /// never send malformed messages.
    try {
      await client.connect();
      print('MQTT client connected to ${settingsService.getIpAddress()}:${settingsService.getPort()}');
    } on NoConnectionException catch (e) {
      // Raised by the client when connection fails.
      print('EXAMPLE::client exception - $e');
      client.disconnect();
    } on SocketException catch (e) {
      // Raised by the socket layer
      print('EXAMPLE::socket exception - $e');
      client.disconnect();
    }

    /// Check we are connected
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('EXAMPLE::Mosquitto client connected');
    } else {
      /// Use status here rather than state if you also want the broker return code.
      print(
        'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}',
      );
      client.disconnect();
      client = null;
      //exit(-1);
    }

    /// Ok, lets try a subscription
    // print('EXAMPLE::Subscribing to the test/lol topic');
    // const topic = 'test/lol'; // Not a wildcard topic
    // client.subscribe(topic, MqttQos.atMostOnce);

    /// The client has a change notifier object(see the Observable class) which we then listen to to get
    /// notifications of published updates to each subscribed topic.
    /// In general you should listen here as soon as possible after connecting, you will not receive any
    /// publish messages until you do this.
    /// Also you must re-listen after disconnecting.
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );

      /// The above may seem a little convoluted for users only interested in the
      /// payload, some users however may be interested in the received publish message,
      /// lets not constrain ourselves yet until the package has been in the wild
      /// for a while.
      /// The payload is a byte buffer, this will be specific to the topic
      print(
        'EXAMPLE::Change notification:: topic is <${c[0].topic}>, payload is <-- $pt -->',
      );
      print('');
    });

    /// If needed you can listen for published messages that have completed the publishing
    /// handshake which is Qos dependant. Any message received on this stream has completed its
    /// publishing handshake with the broker.
    // client.published!.listen((MqttPublishMessage message) {
    //   print(
    //     'EXAMPLE::Published notification:: topic is ${message.variableHeader!.topicName}, with Qos ${message.header!.qos}',
    //   );
    // });

    /// Lets publish to our topic
    /// Use the payload builder rather than a raw buffer
    /// Our known topic to publish to
    // const pubTopic = 'Dart/Mqtt_client/testtopic';
    // final builder = MqttClientPayloadBuilder();
    // builder.addString('Hello from mqtt_client');

    // /// Subscribe to it
    // print('EXAMPLE::Subscribing to the Dart/Mqtt_client/testtopic topic');
    // client.subscribe(pubTopic, MqttQos.exactlyOnce);

    // /// Publish it
    // print('EXAMPLE::Publishing our topic');
    // client.publishMessage(pubTopic, MqttQos.exactlyOnce, builder.payload!);

    // sayCounts();
    // /// Ok, we will now sleep a while, in this gap you will see ping request/response
    // /// messages being exchanged by the keep alive mechanism.
    // print('EXAMPLE::Sleeping....');
    // await MqttUtilities.asyncSleep(60);

    // sayCounts();

    // /// Print the ping/pong cycle latency data before disconnecting.
    // print('EXAMPLE::Keep alive latencies');
    // print(
    //   'The latency of the last ping/pong cycle is ${client.lastCycleLatency} milliseconds',
    // );
    // print(
    //   'The average latency of all the ping/pong cycles is ${client.averageCycleLatency} milliseconds',
    // );

    /// Finally, unsubscribe and exit gracefully
    // print('EXAMPLE::Unsubscribing');
    // client.unsubscribe(topic);

    /// Wait for the unsubscribe message from the broker if you wish.
    // await MqttUtilities.asyncSleep(2);
    // print('EXAMPLE::Disconnecting');
    // client.disconnect();
    // print('EXAMPLE::Exiting normally');
    return 0;
  }

  void sendData([String dataType = 'Default', String dataId = '', ByteBuffer? data]) async {
    if (client == null) {
      print('MQTT client is not connected.');
      return;
    }

    String topic;
    if (dataId.isNotEmpty) {
      topic = "$dataType/${settingsService.getDeviceName()} $dataId";
    } else {
      topic = "$dataType/${settingsService.getDeviceName()}";
    }

    final builder = MqttClientPayloadBuilder();
    if (data != null) {
      var bytes = Uint8List.view(data);
      Uint8Buffer dataBuffer = Uint8Buffer();
      dataBuffer.addAll(bytes);
      builder.addBuffer(dataBuffer);
    } else {
      builder.addString('No data provided');
    }

    try {
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print('Published message to topic $topic');
    } catch (e) {
      print('Failed to publish message: $e');
    }
  }


  // bool sendData(String topic, String message) {
  //   if (client == null) {
  //     print('MQTT client is not connected.');
  //     return false;
  //   }

  //   final builder = MqttClientPayloadBuilder();
  //   builder.addString(message);

  //   try {
  //     client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  //     print('Published message to topic $topic: $message');
  //     return true;
  //   } catch (e) {
  //     print('Failed to publish message: $e');
  //     return false;
  //   }
  // }

  void disconnect() {
    if (client != null) {
      client.unsubscribe();
      client.disconnect();
      client = null;
    }
  }

  void reconnect() {
    disconnect();
    connect();
  }

  /// The subscribed callback
  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
  }

  void sayCounts() {
    print('EXAMPLE:: Ping count is $pingCount');
    print('EXAMPLE:: Pong count is $pongCount');
  }

  /// The unsolicited disconnect callback
  void onDisconnected() {
    print('EXAMPLE::OnDisconnected client callback - Client disconnection');
    if (client.connectionStatus!.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited) {
      print('EXAMPLE::OnDisconnected callback is solicited, this is correct');
    } else {
      print(
        'EXAMPLE::OnDisconnected callback is unsolicited or none, this is incorrect - exiting',
      );
      //exit(-1);
    }
    if (pongCount == 3) {
      print('EXAMPLE:: Pong count is correct');
    } else {
      print('EXAMPLE:: Pong count is incorrect, expected 3. actual $pongCount');
    }
    if (pingCount == 3) {
      print('EXAMPLE:: Ping count is correct');
    } else {
      print('EXAMPLE:: Ping count is incorrect, expected 3. actual $pingCount');
    }
  }

  /// The successful connect callback
  void onConnected() {
    print(
      'EXAMPLE::OnConnected client callback - Client connection was successful',
    );
  }

  /// Pong callback
  void pong() {
    // print('EXAMPLE::Ping response client callback invoked');
    pongCount++;
    // print(
    //   'EXAMPLE::Latency of this ping/pong cycle is ${client.lastCycleLatency} milliseconds',
    // );
  }

  /// Ping callback
  void ping() {
    // print('EXAMPLE::Ping sent client callback invoked');
    pingCount++;
  }
}

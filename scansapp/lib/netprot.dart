/*
Abstraact class for network protocol. Will want to try MQTT and UDP Multicast
 */

import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

abstract class NetworkInterface {
  String ipAddr = 'localhost';
  // String ipAddr = 'test.mosquitto.org';

  bool initNetwork();

  bool sendData(String deviceId, String dataId, Object data);

  void closeNetwork();

  String getIpAddr() {
    return ipAddr;
  }
}

class MQTTtNetwork extends NetworkInterface {
  // example at https://github.com/shamblett/mqtt_client/blob/master/example/mqtt_server_client.dart
  var client;

  var pongCount = 0; // Pong counter
  var pingCount = 0; // Ping counter

  final topic = 'logger/button'; // Not a wildcard topic

  @override
  bool initNetwork() {
    client = MqttServerClient(getIpAddr(), '');
    client.logging(on: false);

    /// Set the correct MQTT protocol for mosquito
    client.setProtocolV311();

    /// If you intend to use a keep alive you must set it here otherwise keep alive will be disabled.
    client.keepAlivePeriod = 20;

    /// The connection timeout period can be set, the default is 5 seconds.
    /// if [client.socketTimeout] is set then this will take precedence and this setting will be
    /// disabled.
    client.connectTimeoutPeriod = 2000; // milliseconds

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
        .withClientIdentifier('Mqtt_Loggerclient')
        .withWillTopic(
          'willtopic',
        ) // If you set this you must set a will message
        .withWillMessage('My Will message')
        .startClean() // Non persistent session for testing
        .withWillQos(MqttQos.atLeastOnce);
    print('EXAMPLE::Mosquitto client connecting....');
    client.connectionMessage = connMess;

    /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
    /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
    /// never send malformed messages.
    try {
      client.connect();
    } on NoConnectionException catch (e) {
      // Raised by the client when connection fails.
      print('EXAMPLE::client exception - $e');
      client.disconnect();
    } on SocketException catch (e) {
      // Raised by the socket layer
      print('EXAMPLE::socket exception - $e');
      client.disconnect();
    }

    print('EXAMPLE::Connect has been called. What\'s happening now ?.');

    /// Check we are connected
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('EXAMPLE::Mosquitto client connected');
    } else {
      /// Use status here rather than state if you also want the broker return code.
      print(
        'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}',
      );
      client.disconnect();
      // exit(-1);
    }

    /// Ok, lets try a subscription
    // print('EXAMPLE::Subscribing to the test/lol topic');
    // client.subscribe(topic, MqttQos.atMostOnce);

    /// The client has a change notifier object(see the Observable class) which we then listen to to get
    /// notifications of published updates to each subscribed topic.
    /// In general you should listen here as soon as possible after connecting, you will not receive any
    /// publish messages until you do this.
    /// Also you must re-listen after disconnecting.
    // client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
    //   final recMess = c![0].payload as MqttPublishMessage;
    //   final pt = MqttPublishPayload.bytesToStringAsString(
    //     recMess.payload.message,
    //   );

    //   /// The above may seem a little convoluted for users only interested in the
    //   /// payload, some users however may be interested in the received publish message,
    //   /// lets not constrain ourselves yet until the package has been in the wild
    //   /// for a while.
    //   /// The payload is a byte buffer, this will be specific to the topic
    //   print(
    //     'EXAMPLE::Change notification:: topic is <${c[0].topic}>, payload is <-- $pt -->',
    //   );
    //   print('');
    // });
    
    print('EXAMPLE::Start listen');

    /// If needed you can listen for published messages that have completed the publishing
    /// handshake which is Qos dependant. Any message received on this stream has completed its
    /// publishing handshake with the broker.
    // client.published!.listen((MqttPublishMessage message) {
    //   print(
    //     'EXAMPLE::Published notification:: topic is ${message.variableHeader!.topicName}, with Qos ${message.header!.qos}',
    //   );
    // });
    print('EXAMPLE::End listen');

    return true;
  }

  @override
  bool sendData(String deviceId, String dataId, Object data) {
    /// Lets publish to our topic
    /// Use the payload builder rather than a raw buffer
    /// Our known topic to publish to
    // const pubTopic = 'Dart/Mqtt_client/testtopic';
    const pubTopic = 'logger/app';
    final builder = MqttClientPayloadBuilder();
    builder.addString(deviceId);
    builder.addString(dataId);
    builder.addString('Hello from mqtt_client');

    /// Subscribe to it
    print('EXAMPLE::Subscribing to the Dart/Mqtt_client/testtopic topic');
    client.subscribe(pubTopic, MqttQos.exactlyOnce);

    /// Publish it
    print('EXAMPLE::Publishing our topic');
    client.publishMessage(pubTopic, MqttQos.exactlyOnce, builder.payload!);

    return true;
  }

  @override
  void closeNetwork() {
    /// Finally, unsubscribe and exit gracefully
    print('EXAMPLE::Unsubscribing');
    client.unsubscribe(topic);

    /// Wait for the unsubscribe message from the broker if you wish.
    MqttUtilities.asyncSleep(2);
    print('EXAMPLE::Disconnecting');
    client.disconnect();
    print('EXAMPLE::Exiting normally');
  }

  /// The subscribed callback
  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
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
      exit(-1);
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
    print('EXAMPLE::Ping response client callback invoked');
    pongCount++;
    print(
      'EXAMPLE::Latency of this ping/pong cycle is ${client.lastCycleLatency} milliseconds',
    );
  }

  /// Ping callback
  void ping() {
    print('EXAMPLE::Ping sent client callback invoked');
    pingCount++;
  }
}

class MulticastNetwork extends NetworkInterface {
  int multicastPort = 4567;

  @override
  bool initNetwork() {
    return true;
  }

  @override
  bool sendData(String deviceId, String dataId, Object data) {
    return true;
  }

  @override
  void closeNetwork() {}
}

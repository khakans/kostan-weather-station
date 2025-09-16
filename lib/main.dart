import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Station',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Weather Station'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final String broker = dotenv.env['MQTT_BROKER'] ?? '';
  final int port = int.parse(dotenv.env['MQTT_PORT'] ?? '1883');
  final String clientIdentifier = dotenv.env['MQTT_CLIENT_IDENTIFIER'] ?? '';

  late MqttServerClient client;
  MqttConnectionState? connectionState;

  int _tempVal = 0;
  int _humiVal = 0;
  int _lumiVal = 0;
  int _airqVal = 0;
  int _airpVal = 0;
  int _altiVal = 0;

  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? subscription;

  void _subscribeToTopic(String topic) {
    if (connectionState == MqttConnectionState.connected) {
      client.subscribe(topic, MqttQos.exactlyOnce);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: Image.asset("assets/icon/weather.png", scale: 6),
        title: const Center(
          child: Text(
            "Weather Station",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        actions: <Widget>[
          SizedBox(
            width: 43,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _connect,
              child: const Icon(Icons.play_arrow, color: Colors.blue, size: 37),
            ),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        children: <Widget>[
          CardSensor(
            iconVar: "assets/icon/icon_temperature.png",
            textVar: "TEMPERATURE",
            valuVar: "$_tempVal",
            unitVar: "°C",
          ),
          CardSensor(
            iconVar: "assets/icon/icon_humidity.png",
            textVar: "HUMIDITY",
            valuVar: "$_humiVal",
            unitVar: "%",
          ),
          CardSensor(
            iconVar: "assets/icon/icon_luminosity.png",
            textVar: "LUMINOSITY",
            valuVar: "$_lumiVal",
            unitVar: "Lux",
          ),
          CardSensor(
            iconVar: "assets/icon/icon_airquality.png",
            textVar: "AIR QUALITY",
            valuVar: "$_airqVal",
            unitVar: "ppm",
          ),
          CardSensor(
            iconVar: "assets/icon/icon_airpressure.png",
            textVar: "AIR PRESSURE",
            valuVar: "$_airpVal",
            unitVar: "hPa",
          ),
          CardSensor(
            iconVar: "assets/icon/icon_altitude.png",
            textVar: "ACT ALTITUDE",
            valuVar: "$_altiVal",
            unitVar: "M",
          ),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    client = MqttServerClient(broker, clientIdentifier);
    client.port = port;
    client.logging(on: true);
    client.keepAlivePeriod = 30;
    client.onDisconnected = _onDisconnected;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      _disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      // [MQTT client] connected
      setState(() {
        connectionState = client.connectionStatus!.state;
      });
    } else {
      // [MQTT client] ERROR: connection failed
      _disconnect();
      return;
    }

    subscription = client.updates!.listen(_onMessage);
    _subscribeToTopic("kws/sensorKws");
  }

  void _disconnect() {
    // [MQTT client] disconnect
    client.disconnect();
    _onDisconnected();
  }

  void _onDisconnected() {
    // [MQTT client] on disconnected'
    setState(() {
      connectionState = client.connectionStatus?.state;
    });
    subscription?.cancel();
    subscription = null;
    // [MQTT client] MQTT client disconnected
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> event) {
    final recMess = event[0].payload as MqttPublishMessage;
    final message = MqttPublishPayload.bytesToStringAsString(
      recMess.payload.message,
    );
    var receiveData = message.split(",");
    if (receiveData.length >= 6) {
      setState(() {
        _tempVal = int.tryParse(receiveData[0]) ?? 0;
        _humiVal = int.tryParse(receiveData[1]) ?? 0;
        _lumiVal = int.tryParse(receiveData[2]) ?? 0;
        _airqVal = int.tryParse(receiveData[3]) ?? 0;
        _airpVal = int.tryParse(receiveData[4]) ?? 0;
        _altiVal = int.tryParse(receiveData[5]) ?? 0;
      });
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    client.disconnect();
    super.dispose();
  }
}

class CardSensor extends StatelessWidget {
  final String iconVar;
  final String textVar;
  final String valuVar;
  final String unitVar;

  const CardSensor({
    super.key,
    required this.iconVar,
    required this.textVar,
    required this.valuVar,
    required this.unitVar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue,
      margin: const EdgeInsets.all(10),
      child: Column(
        children: <Widget>[
          ListTile(
            leading: Image.asset(iconVar),
            title: Text(
              textVar,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            valuVar,
            style: const TextStyle(
              fontSize: 80,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unitVar,
            style: const TextStyle(
              fontSize: 25,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

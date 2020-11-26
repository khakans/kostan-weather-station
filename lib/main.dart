import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kostan Weather Station',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String broker = 'broker.hivemq.com';
  int port = 1883;
  String clientIdentifier = 'kws';

  mqtt.MqttClient client;
  mqtt.MqttConnectionState connectionState;

  int _tempVal = 0;
  int _humiVal = 0;
  int _lumiVal = 0;
  int _airqVal = 0;
  int _airpVal = 0;
  int _altiVal = 0;

  StreamSubscription subscription;

  void _subscribeToTopic(String topic) {
    if (connectionState == mqtt.MqttConnectionState.connected) {
      print('[MQTT client] Subscribing to ${topic.trim()}');
      client.subscribe(topic, mqtt.MqttQos.exactlyOnce);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: Image.asset(
          "assets/icon/weather.png",
          scale: 6,
        ),
        title: Center(
          child: Text("Kostan Weather Station",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              )),
        ),
        actions: <Widget>[
          Container(
            width: 43,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _connect,
              child: Icon(
                Icons.play_arrow,
                color: Colors.blue,
                size: 37.0,
              ),
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

  void _connect() async {
    client = mqtt.MqttClient(broker, '');
    client.port = port;
    client.logging(on: true);
    client.keepAlivePeriod = 30;
    client.onDisconnected = _onDisconnected;

    final mqtt.MqttConnectMessage connMess = mqtt.MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean() // Non persistent session for testing
        .keepAliveFor(30)
        .withWillQos(mqtt.MqttQos.atMostOnce);
    print('[MQTT client] MQTT client connecting....');
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      print(e);
      _disconnect();
    }

    /// Check if we are connected
    // ignore: deprecated_member_use
    if (client.connectionState == mqtt.MqttConnectionState.connected) {
      print('[MQTT client] connected');
      setState(() {
        // ignore: deprecated_member_use
        connectionState = client.connectionState;
      });
    } else {
      print('[MQTT client] ERROR: MQTT client connection failed - '
          // ignore: deprecated_member_use
          'disconnecting, state is ${client.connectionState}');
      _disconnect();
    }
    subscription = client.updates.listen(_onMessage);

    _subscribeToTopic("kws/sensorKws");
  }

  void _disconnect() {
    print('[MQTT client] _disconnect()');
    client.disconnect();
    _onDisconnected();
  }

  void _onDisconnected() {
    print('[MQTT client] _onDisconnected');
    setState(() {
      // ignore: deprecated_member_use
      connectionState = client.connectionState;
      client = null;
      subscription.cancel();
      subscription = null;
    });
    print('[MQTT client] MQTT client disconnected');
  }

  void _onMessage(List<mqtt.MqttReceivedMessage> event) {
    final mqtt.MqttPublishMessage recMess =
        event[0].payload as mqtt.MqttPublishMessage;
    final String message =
        mqtt.MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    print("${event.length} | ${event[0].topic} : $message");
    var receiveData = parsingRawData(message, ",");
    setState(() {
      _tempVal = int.parse(receiveData[0]);
      _humiVal = int.parse(receiveData[1]);
      _lumiVal = int.parse(receiveData[2]);
      _airqVal = int.parse(receiveData[3]);
      _airpVal = int.parse(receiveData[4]);
      _altiVal = int.parse(receiveData[5]);
    });
  }
}

class CardSensor extends StatelessWidget {
  CardSensor({this.iconVar, this.textVar, this.valuVar, this.unitVar});
  final String iconVar;
  final String textVar;
  final String valuVar;
  final String unitVar;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Card(
        color: Colors.blue,
        margin: EdgeInsets.all(10),
        child: Column(
          children: <Widget>[
            ListTile(
              leading: Image.asset(
                iconVar,
              ),
              title: Text(textVar,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  )),
            ),
            Text(valuVar,
                style: TextStyle(
                  fontSize: 80,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                )),
            Text(unitVar,
                style: TextStyle(
                  fontSize: 25,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
      ),
    );
  }
}

List parsingRawData(data, delimiter) {
  var resultData = new List(6);
  resultData = data.toString().split(delimiter);
  return resultData;
}

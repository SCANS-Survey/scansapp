import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'udpprot.dart';

// https://pub.dev/packages/camera/example

var netInterface = UDPNetwork();

void main() {
  // bool ok = netInterface.initNetwork();
  // if (ok == false) {
  //   print('Network interface failed to connect');
  // }
  runApp(const MainApp());
  // print('close network interface');
  // netInterface.closeNetwork();
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Align(
            alignment: Alignment.center,
            child: Text('Logger Buttons'),
          ),
        ),
        body: Expanded(
          child: Container(
            // height: 500,
            color: Colors.black,
            child: ScansButtons(),
          ),
        ),
      ),
    );
  }
}

/// Main page of display containing two buttons and a camera display.
class ScansButtons extends StatelessWidget {
  ObsButton sighting = ObsButton(Colors.green, "Sighting");
  ObsButton resighting = ObsButton(Colors.red, "Resighting");

  ScansButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Flexible(flex: 1, child: sighting),
          Flexible(flex: 1, child: resighting),
        ],
      ),
      // )
    );
  }
}

class ObsButton extends StatelessWidget {
  const ObsButton(this.colour, this.title, {super.key});

  final Color colour;
  final String title;

  void _onPressed() {
    print("Button $title pressed");
    netInterface.sendData("phoneapp", title, Null);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          // backgroundColor: Color.fromRGBO(255, 0, 0, .7),
          backgroundColor: colour,
          foregroundColor: Color.fromRGBO(255, 255, 255, 1.0),
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 34,
          ),

          minimumSize: const Size(
            double.infinity,
            double.infinity,
          ), // <--- this line helped me
        ),
        child: Text(title),
        onPressed: _onPressed,
      ),
    );
  }
}

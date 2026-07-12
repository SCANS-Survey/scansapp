import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'mqttprot.dart';
import 'settings_dialog.dart';
import 'settings_service.dart';
// import 'udpprot.dart';

// var netInterface = UDPNetwork();
final settingsService = SettingsService();
final mqttInterface = MQTTNetProt(settingsService);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await settingsService.init();

  List<CameraDescription> cameras = [];
  try {
    print('*******************************      start MQTT');
    // final  mqt = MQTTNetProt();
    mqttInterface.connect();
    print('*******************return from MQTT connect');

  } catch (e) {
    debugPrint('Failed to initialize MQTT: $e');
  }
  try {
    cameras = await availableCameras();
    print('Available cameras: ${cameras.map((c) => c.name).join(', ')}');
  } catch (e) {
    debugPrint('Failed to initialize cameras: $e');
  }

 runApp(MainApp(cameras: cameras));
}

class MainApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MainApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(cameras: cameras),
    );
  }
}

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({super.key, required this.cameras});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String _deviceName;
  late bool _showCamera;

  @override
  void initState() {
    super.initState();
    _showCamera = settingsService.getShowCamera();
    _deviceName = settingsService.getDeviceName();
    // Keep the screen on while the app is running
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    // Allow screen to lock again when the app is disposed
    WakelockPlus.disable();
    super.dispose();
  }
  
  void _refreshDeviceName() {
    setState(() {
      _deviceName = settingsService.getDeviceName();
    });
  }

  Future<void> _openSettings() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return SettingsDialog(settingsService: settingsService);
      },
    ).then((_) {
          // Refresh device name after dialog closes
          _refreshDeviceName();
        });

    if (mounted && result == true) {
      setState(() {
        _showCamera = settingsService.getShowCamera();
        //settingsService.setShowCamera(_showCamera);
        _deviceName = settingsService.getDeviceName();
          mqttInterface.reconnect(); // Reconnect MQTT after settings change
      });
    }
  }

  void _handleCameraFrame(CameraImage cameraImage, CameraLensDirection lensDirection) {
    try {
      // cameraImage = cameraImage.; // Rotate the image by 90 degrees
      final pngBytes = _encodeCameraImageToPng(cameraImage, lensDirection);
      //print('Camera frame received: ${cameraImage.width} x ${cameraImage.height}, PNG ${pngBytes.length} bytes');
      // pngBytes now contains the encoded PNG in memory.
      // Use pngBytes for transmission, upload, or further processing.
      final pngbytes = pngBytes.buffer;
      mqttInterface.sendData('CameraFrame', '', pngbytes);
    } catch (e, st) {
      debugPrint('Failed to encode camera frame to PNG: $e\n$st');
    }
  }

  Uint8List _encodeCameraImageToPng(CameraImage image, CameraLensDirection lensDirection) {
    var rgbImage = _convertYuv420ToRgb(image);
    if (settingsService.getCameraGreyscale()) {
      rgbImage = img.grayscale(rgbImage);
    }

    // Enforce portrait orientation regardless of sensor. If image is wider
    // than tall, rotate 90 degrees to make it portrait.
    // if (rgbImage.width > rgbImage.height) {
      rgbImage = _rotate90(rgbImage);
    // }

    // // Mirror front camera to match preview.
    // if (lensDirection == CameraLensDirection.front) {
    //   rgbImage = img.flipHorizontal(rgbImage);
    // }

    return Uint8List.fromList(img.encodePng(rgbImage));
  }

  img.Image _convertYuv420ToRgb(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;

    final img.Image rgbImage = img.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      final yRow = yRowStride * y;
      final uvRow = uvRowStride * (y >> 1);

      for (var x = 0; x < width; x++) {
        final yIndex = yRow + x * yPixelStride;
        final uvIndex = uvRow + (x >> 1) * uvPixelStride;

        final yp = yPlane.bytes[yIndex] & 0xff;
        final up = (uPlane.bytes[uvIndex] & 0xff) - 128;
        final vp = (vPlane.bytes[uvIndex] & 0xff) - 128;

        final r = (yp + 1.402 * vp).round().clamp(0, 255);
        final g = (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255);
        final b = (yp + 1.772 * up).round().clamp(0, 255);

        rgbImage.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return rgbImage;
  }

  img.Image _rotate90(img.Image src) {
    final dst = img.Image(width: src.height, height: src.width);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final color = src.getPixel(x, y);
        // Clockwise 90: newX = height - 1 - y, newY = x
        dst.setPixel(src.height - 1 - y, x, color);
      }
    }
    return dst;
  }

  @override
  Widget build(BuildContext context) {
    final rearCamera = widget.cameras.isEmpty
        ? null
        : widget.cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => widget.cameras.first,
          );

    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.center,
          child: Text(_deviceName),
        ),
        actions: [
          // IconButton(
          //   icon: Icon(
          //     _showCamera ? Icons.camera_alt : Icons.camera_alt_outlined,
          //   ),
          //   tooltip: 'Toggle camera preview',
          //   onPressed: () async {
          //     setState(() {
          //       _showCamera = !_showCamera;
          //     });
          //     await settingsService.setShowCamera(_showCamera);
          //   },
          // ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Flexible(
              flex: 1,
              child: ValueListenableBuilder<String>(
                valueListenable: mqttInterface.counterValue,
                builder: (context, pt, child) {
                  final label = (pt.isNotEmpty) ? 'Sighting\n $pt' : 'Sighting';
                  return ObsButton(Colors.green, 'Sighting', label);
                },
              ),
            ),
            if (_showCamera)
              Flexible(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black,
                  ),
                  clipBehavior: Clip.hardEdge,
                                  child: CameraDisplay(
                                    camera: rearCamera,
                                    onFrame: _handleCameraFrame,
                                  ),
                ),
              ),
            Flexible(
              flex: 1,
              child: ObsButton(Colors.red, 'Resighting', 'Resighting'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildMqttStatusBar(),
    );
  }

  Widget _buildMqttStatusBar() {
    return ValueListenableBuilder<MqttConnectionState?>(
      valueListenable: mqttInterface.connectionState,
      builder: (context, state, child) {
        String label;
        Color color;
        switch (state) {
          case MqttConnectionState.connected:
            label = 'MQTT: Connected';
            color = Colors.green;
            break;
          case MqttConnectionState.connecting:
            label = 'MQTT: Connecting';
            color = Colors.orange;
            break;
          case MqttConnectionState.disconnecting:
            label = 'MQTT: Disconnecting';
            color = Colors.orangeAccent;
            break;
          case MqttConnectionState.disconnected:
          default:
            label = 'MQTT: Disconnected';
            color = Colors.red;
        }

        return Container(
          height: 36,
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.cloud, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${settingsService.getIpAddress()}:${settingsService.getPort()}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}


class CameraDisplay extends StatefulWidget {
  final CameraDescription? camera;
  final void Function(CameraImage imageData, CameraLensDirection lensDirection) onFrame;

  const CameraDisplay({
    super.key,
    required this.camera,
    required this.onFrame,
  });

  @override
  State<CameraDisplay> createState() => _CameraDisplayState();
}

class _CameraDisplayState extends State<CameraDisplay> {
  CameraController? _controller;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isInitializing = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void didUpdateWidget(covariant CameraDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera?.name != widget.camera?.name) {
      _controller?.dispose();
      _controller = null;
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (widget.camera == null) return;
    if (_isInitializing) return;

    _isInitializing = true;
    final controller = CameraController(
      widget.camera!,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,

    );

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _cameraError = null;
      });
      controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Camera initialize failed: $e');
      if (!mounted) return;
      setState(() {
        _cameraError = e.toString();
      });
    } finally {
      _isInitializing = false;
    }
  }

  void _processCameraImage(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastFrameTime) < const Duration(seconds: 1)) {
      return;
    }
    _lastFrameTime = now;

    // Pass only the lens direction; rotation is enforced to portrait in the
    // encoder so we don't rely on device sensor orientation.
    final lensDirection = _controller?.description.lensDirection ?? CameraLensDirection.back;
    widget.onFrame(image, lensDirection);
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    /*
      * Concatenates the byte data from all planes into a single Uint8List.
      * This is necessary because CameraImage provides separate byte buffers for each plane.
      */
    final totalBytes = planes.fold<int>(0, (sum, plane) => sum + plane.bytes.length);
    final bytes = Uint8List(totalBytes);
    var offset = 0;
    for (final plane in planes) {
      bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.camera == null) {
      return Container(
        color: Colors.grey[900],
        alignment: Alignment.center,
        child: const Text(
          'Rear camera unavailable',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    if (_cameraError != null) {
      return Container(
        color: Colors.grey[900],
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          'Camera error: $_cameraError',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: CameraPreview(_controller!),
    );
  }
}

class ObsButton extends StatelessWidget {
  const ObsButton(this.colour, this.title, this.label, {super.key});

  final Color colour;
  final String title;
  final String label;

  void _onPressed() {
    print('Button $title pressed');
    mqttInterface.sendData('LoggerButton',   title);
  }

  @override
  Widget build(BuildContext context) {
    String? childText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colour,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 34,
          ),
          minimumSize: const Size(double.infinity, 500.0),
        ),
                  // final title = (pt.isNotEmpty) ? 'Sighting\n $pt' : 'Sighting';
        child: Text(label, textAlign: TextAlign.center),
        onPressed: _onPressed,
      ),
    );
  }
}

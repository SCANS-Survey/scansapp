import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'mqttprot.dart';
import 'settings_dialog.dart';
import 'settings_service.dart';
import 'udpprot.dart';

var netInterface = UDPNetwork();
final settingsService = SettingsService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await settingsService.init();

  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
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
        _deviceName = settingsService.getDeviceName();
      });
    }
  }

  void _handleCameraFrame(CameraImage cameraImage) {
    var imageData = cameraImage.planes;
    var plane0 = imageData[1].bytes;
    print('Camera frame received: ${plane0.length} bytes, ${cameraImage.width} x ${cameraImage.height}');
    // TODO: Replace this with any additional processing needed.
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
          IconButton(
            icon: Icon(
              _showCamera ? Icons.camera_alt : Icons.camera_alt_outlined,
            ),
            tooltip: 'Toggle camera preview',
            onPressed: () async {
              setState(() {
                _showCamera = !_showCamera;
              });
              await settingsService.setShowCamera(_showCamera);
            },
          ),
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
              child: ObsButton(Colors.green, 'Sighting'),
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
              child: ObsButton(Colors.red, 'Resighting'),
            ),
          ],
        ),
      ),
    );
  }
}

class CameraDisplay extends StatefulWidget {
  final CameraDescription? camera;
  final void Function(CameraImage imageData) onFrame;

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

    // final bytes = _concatenatePlanes(image.planes);
    widget.onFrame(image);
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
  const ObsButton(this.colour, this.title, {super.key});

  final Color colour;
  final String title;

  void _onPressed() {
    print('Button $title pressed');
    netInterface.sendData('phoneapp', title, Null);
  }

  @override
  Widget build(BuildContext context) {
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
        child: Text(title),
        onPressed: _onPressed,
      ),
    );
  }
}

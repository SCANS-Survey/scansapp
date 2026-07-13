import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'settings_service.dart';
import 'package:record/record.dart';
import 'mqttprot.dart';

final recorder = AudioRecorder();

final int sampleRate = 8000;
final int nChannels = 1;

final recordConfig = RecordConfig(
  encoder: AudioEncoder.pcm16bits,
  sampleRate: 8000,
  numChannels: 1,
  autoGain: true,
  echoCancel: true,
  noiseSuppress: true,
);

//https://docs.flutter.dev/cookbook/audio/record
class LoggerAudio {

  final SettingsService settingsService;

  final MQTTNetProt mqttInterface;

  LoggerAudio({required this.settingsService, required this.mqttInterface});

  // Placeholder for audio capture and sending logic
  Future<void> startAudioCapture() async {
    
    if (await recorder.hasPermission()) {
      print('Permission granted for audio recording.');
    } else {
      print('Permission denied for audio recording.');
      return;
    }

    // Start recording
    await recorder.startStream(recordConfig);
    print('Audio recording started.');

    // Listen to the audio stream
    final stream = await recorder.startStream(recordConfig);
    stream.listen((data) {
      // Handle audio data (Uint8List)
      // Send the audio data to the base station
      // print('Audio data sent: ${data.length} bytes is ${data.buffer.lengthInBytes}');
      var goodData = data.sublist(5, data.lengthInBytes);
      mqttInterface.sendData("AudioData", "", goodData.buffer);
    });
  }

  Future<void> stopAudioCapture() async {
    // Stop recording
    await recorder.stop();
    print('Audio recording stopped.');
  }

  Future<void> toggleAudioCapture() async {
    bool isRecording = await recorder.isRecording();
    if (isRecording) {
      await stopAudioCapture();
    } else {
      await startAudioCapture();
    }
  }

  Future<void> stoporstart() async {
    bool isRec = await recorder.isRecording();
    if (settingsService.getCaptureAudio() && !isRec) {
      startAudioCapture();
    } else {
      stopAudioCapture();
    }
  }

}

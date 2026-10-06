import 'dart:async';
import 'dart:typed_data';

import 'settings_service.dart';
import 'package:record/record.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
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
  streamBufferSize: 800,
);

//https://docs.flutter.dev/cookbook/audio/record
class LoggerAudio {

  final SettingsService settingsService;

  final MQTTNetProt mqttInterface;

  Future<void>? _playbackSetup;
  Future<void> _playbackQueue = Future<void>.value();
  int? _pendingAudioByte;

  LoggerAudio({required this.settingsService, required this.mqttInterface}) {
    mqttInterface.onDRVoice = playReceivedAudio;
  }

  void playReceivedAudio(Uint8List audioData) {
    if (audioData.isEmpty) return;

    final pendingByte = _pendingAudioByte;
    final combinedData = Uint8List(audioData.length + (pendingByte == null ? 0 : 1));
    var dataOffset = 0;
    if (pendingByte != null) {
      combinedData[0] = pendingByte;
      dataOffset = 1;
    }
    combinedData.setRange(dataOffset, combinedData.length, audioData);

    final completeByteCount = combinedData.length & ~1;
    _pendingAudioByte = completeByteCount < combinedData.length
        ? combinedData.last
        : null;
    if (completeByteCount == 0) return;

    final pcmBytes = Uint8List.sublistView(combinedData, 0, completeByteCount);
    final pcm = PcmArrayInt16(bytes: ByteData.sublistView(pcmBytes));
    _playbackQueue = _playbackQueue
        .then((_) async {
          _playbackSetup ??= FlutterPcmSound.setup(
            sampleRate: sampleRate,
            channelCount: nChannels,
          );
          await _playbackSetup;
          await FlutterPcmSound.feed(pcm);
        })
        .catchError((Object error, StackTrace stackTrace) {
          print('Failed to play received audio: $error');
        });
  }

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
      var goodData = data.sublist(0, data.lengthInBytes);
      mqttInterface.sendData("Logger/AudioData", '', goodData.buffer);
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

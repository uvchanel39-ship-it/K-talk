import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorder {
  VoiceRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  static const maxDuration = Duration(seconds: 10);
  static const minDuration = Duration(milliseconds: 500);

  final AudioRecorder _recorder;
  String? _path;
  DateTime? _startedAt;

  Future<bool> isSupported() => _recorder.isEncoderSupported(AudioEncoder.opus);

  Future<void> start() async {
    if (await _recorder.isRecording()) {
      throw StateError('A voice recording is already active');
    }
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission is required');
    }
    if (!await isSupported()) {
      throw StateError('Opus recording is not supported on this device');
    }
    final directory = await getTemporaryDirectory();
    _path =
        '${directory.path}/voice_${DateTime.now().microsecondsSinceEpoch}.webm';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.opus,
        sampleRate: 48000,
        bitRate: 6000,
        numChannels: 1,
      ),
      path: _path!,
    );
    _startedAt = DateTime.now();
  }

  Future<Uint8List?> stop() async {
    final path = await _recorder.stop();
    final started = _startedAt;
    _startedAt = null;
    _path = null;
    if (path == null ||
        started == null ||
        DateTime.now().difference(started) < minDuration) {
      if (path != null) await _deleteQuietly(path);
      return null;
    }
    final bytes = await File(path).readAsBytes();
    await _deleteQuietly(path);
    return bytes;
  }

  Future<void> cancel() async {
    final path = await _recorder.stop();
    _startedAt = null;
    _path = null;
    if (path != null) await _deleteQuietly(path);
  }

  Future<void> dispose() => _recorder.dispose();

  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      return;
    }
  }
}

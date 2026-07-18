import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/video_file.dart';

class FFprobeService {
  static Future<List<VideoFile>> scanDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final exts = {'.mp4', '.mov', '.mkv', '.avi', '.m4v', '.ts', '.webm'};
    final files = await dir
        .list()
        .where((e) => e is File && exts.contains(p.extension(e.path).toLowerCase()))
        .map((e) => e as File)
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));

    final results = <VideoFile>[];
    for (final f in files) {
      final info = await _probe(f.path);
      if (info != null) results.add(info);
    }
    return results;
  }

  static Future<VideoFile?> _probe(String path) async {
    try {
      final proc = await Process.run(
        'ffprobe',
        [
          '-v', 'quiet',
          '-print_format', 'json',
          '-show_entries',
          'stream=index,codec_type,codec_name,channels,sample_rate,bit_rate:format=duration,size',
          path,
        ],
      ).timeout(const Duration(seconds: 30));
      if (proc.exitCode != 0) return null;

      final data = jsonDecode(proc.stdout as String) as Map<String, dynamic>;
      final fmt = data['format'] as Map<String, dynamic>? ?? {};
      final streams = data['streams'] as List<dynamic>? ?? [];

      final tracks = streams
          .where((s) => (s as Map<String, dynamic>)['codec_type'] == 'audio')
          .map((s) => AudioTrack.fromJson(s as Map<String, dynamic>))
          .toList();

      return VideoFile(
        path: path,
        name: p.basename(path),
        size: int.tryParse(fmt['size']?.toString() ?? '') ?? 0,
        duration: double.tryParse(fmt['duration']?.toString() ?? '') ?? 0,
        tracks: tracks,
      );
    } catch (_) {
      return null;
    }
  }
}

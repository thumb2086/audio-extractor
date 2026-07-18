import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

typedef LogCallback = void Function(String line);

class ExtractService {
  static Future<void> extractTracks({
    required List<String> sourcePaths,
    required List<List<int>> trackIndices,
    required String outputDir,
    required String format,
    required String bitrate,
    required LogCallback onLog,
    required VoidCallback onProgress,
    bool Function()? isCanceled,
  }) async {
    final outDir = Directory(outputDir);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    for (int fi = 0; fi < sourcePaths.length; fi++) {
      if (isCanceled != null && isCanceled()) break;
      final src = sourcePaths[fi];
      final stem = p.basenameWithoutExtension(src);

      for (final tidx in trackIndices[fi]) {
        if (isCanceled != null && isCanceled()) break;
        final ext = _ext(format);
        final outName = '${stem}_track$tidx$ext';
        final outPath = p.join(outputDir, outName);

        if (await File(outPath).exists()) {
          onLog('  SKIP $outName (exists)');
          onProgress();
          continue;
        }

        final args = <String>[
          '-y',
          '-i', src,
          '-map', '0:$tidx',
          '-vn',
        ];

        if (format == 'aac') {
          args.addAll(['-c:a', 'aac', '-b:a', bitrate]);
        } else if (format == 'flac') {
          args.addAll(['-c:a', 'flac']);
        } else if (format == 'wav') {
          args.addAll(['-c:a', 'pcm_s16le']);
        }
        args.add(outPath);

        try {
          final proc = await Process.run('ffmpeg', args)
              .timeout(const Duration(hours: 1));
          if (proc.exitCode == 0) {
            onLog('  OK  $outName');
          } else {
            var err = proc.stderr as String;
            if (err.length > 200) err = err.substring(0, 200);
            onLog('  FAIL $outName: ${err.replaceAll('\n', ' ')}');
          }
        } catch (e) {
          onLog('  FAIL $outName: $e');
        }
        onProgress();
      }
    }
  }

  static String _ext(String format) {
    switch (format) {
      case 'aac': return '.aac';
      case 'wav': return '.wav';
      case 'flac': return '.flac';
      default: return '.aac';
    }
  }
}

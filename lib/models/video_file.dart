class AudioTrack {
  final int index;
  final String codec;
  final int channels;
  final int sampleRate;
  final int bitRate;

  AudioTrack({
    required this.index,
    required this.codec,
    required this.channels,
    required this.sampleRate,
    required this.bitRate,
  });

  factory AudioTrack.fromJson(Map<String, dynamic> json) => AudioTrack(
        index: json['index'] as int,
        codec: json['codec_name'] as String? ?? '?',
        channels: json['channels'] as int? ?? 0,
        sampleRate: int.tryParse(json['sample_rate']?.toString() ?? '') ?? 0,
        bitRate: int.tryParse(json['bit_rate']?.toString() ?? '') ?? 0,
      );

  String get channelsLabel => channels == 0 ? '?' : '${channels}ch';
  String get sampleRateLabel => sampleRate == 0 ? '?' : '${(sampleRate / 1000).toStringAsFixed(0)}kHz';
  String get bitRateLabel => bitRate == 0 ? '?' : '${(bitRate / 1000).toStringAsFixed(0)}k';
}

class VideoFile {
  final String path;
  final String name;
  final int size;
  final double duration;
  final List<AudioTrack> tracks;

  VideoFile({
    required this.path,
    required this.name,
    required this.size,
    required this.duration,
    required this.tracks,
  });

  int get trackCount => tracks.length;

  String get sizeLabel {
    final b = size;
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
    if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)}MB';
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)}GB';
  }

  String get durationLabel {
    final total = duration.toInt();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}m';
    return '${m}m${s.toString().padLeft(2, '0')}s';
  }
}

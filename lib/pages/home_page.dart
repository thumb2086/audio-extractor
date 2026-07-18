import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/video_file.dart';
import '../services/ffprobe_service.dart';
import '../services/extract_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _sourceDir;
  String _outputDir = '';
  bool _scanning = false;
  List<VideoFile> _files = [];
  Set<int> _selected = {};
  String _format = 'aac';
  String _bitrate = '384k';
  bool _running = false;
  bool _cancelFlag = false;
  int _progressDone = 0;
  int _progressTotal = 0;
  final List<String> _logs = [];
  final ScrollController _logScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final home = Platform.environment['USERPROFILE'] ?? '';
    _sourceDir = p.joinAll([home, 'Videos', 'Overwolf', 'Insights Capture']);
    if (!Directory(_sourceDir!).existsSync()) {
      _sourceDir = p.join(home, 'Videos');
    }
    _outputDir = p.join(_sourceDir!, 'extracted_audio');
  }

  Future<void> _pickSource() async {
    final d = await FilePicker.getDirectoryPath();
    if (d != null) {
      setState(() => _sourceDir = d);
      _scan();
    }
  }

  Future<void> _scan() async {
    if (_sourceDir == null) return;
    setState(() {
      _scanning = true;
      _files = [];
      _selected = {};
      _logs.clear();
    });

    final files = await FFprobeService.scanDirectory(_sourceDir!);
    if (!mounted) return;

    setState(() {
      _files = files;
      _scanning = false;
      for (int i = 0; i < files.length; i++) {
        if (files[i].trackCount > 0) _selected.add(i);
      }
    });
  }

  void _selectAll() => setState(() => _selected = {for (int i = 0; i < _files.length; i++) i});
  void _selectNone() => setState(() => _selected = {});
  void _selectByTrackCount(int n) {
    setState(() {
      _selected = {};
      for (int i = 0; i < _files.length; i++) {
        if (_files[i].trackCount == n) _selected.add(i);
      }
    });
  }

  Future<void> _pickOutput() async {
    final d = await FilePicker.getDirectoryPath();
    if (d != null) setState(() => _outputDir = d);
  }

  Future<void> _start() async {
    if (_selected.isEmpty) {
      _snack('No files selected');
      return;
    }
    setState(() {
      _running = true;
      _cancelFlag = false;
      _progressDone = 0;
      _logs.clear();
      _progressTotal = 0;
      for (final i in _selected) _progressTotal += _files[i].trackCount;
    });

    final sources = _selected.map((i) => _files[i].path).toList();
    final tracks = _selected.map((i) => _files[i].tracks.map((t) => t.index).toList()).toList();

    await ExtractService.extractTracks(
      sourcePaths: sources,
      trackIndices: tracks,
      outputDir: _outputDir,
      format: _format,
      bitrate: _bitrate,
      isCanceled: () => _cancelFlag,
      onLog: (line) {
        if (!mounted) return;
        setState(() => _logs.add(line));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScroll.hasClients) {
            _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
          }
        });
      },
      onProgress: () {
        if (!mounted) return;
        setState(() => _progressDone++);
      },
    );

    if (!mounted) return;
    setState(() => _running = false);
    _snack('Done — $_progressDone tracks processed');
  }

  void _doCancel() {
    _cancelFlag = true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Extractor'),
        centerTitle: true,
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSourceCard(theme),
        const SizedBox(height: 12),
        _buildFileCard(theme),
        const SizedBox(height: 12),
        _buildSettingsCard(theme),
        if (_running || _progressDone > 0) ...[
          const SizedBox(height: 12),
          _buildProgressCard(theme),
        ],
        if (_logs.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildLogCard(theme),
        ],
      ],
    );
  }

  Widget _buildSourceCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_open, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Source Directory', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _sourceDir ?? '(none)',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _running ? null : _pickSource,
                  icon: const Icon(Icons.folder, size: 18),
                  label: const Text('Browse'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _running ? null : _scan,
                  icon: _scanning
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Scan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_library, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Files', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('${_files.length} files, ${_selected.length} selected',
                    style: theme.textTheme.bodySmall),
              ],
            ),
            if (_scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_files.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No files found. Select a directory and scan.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: const Text('All'),
                    onPressed: _running ? null : _selectAll,
                    visualDensity: VisualDensity.compact,
                  ),
                  ActionChip(
                    label: const Text('None'),
                    onPressed: _running ? null : _selectNone,
                    visualDensity: VisualDensity.compact,
                  ),
                  ActionChip(
                    label: const Text('1-Track'),
                    onPressed: _running ? null : () => _selectByTrackCount(1),
                    visualDensity: VisualDensity.compact,
                  ),
                  ActionChip(
                    label: const Text('5-Track'),
                    onPressed: _running ? null : () => _selectByTrackCount(5),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 280,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 40,
                    columnSpacing: 12,
                    columns: [
                      DataColumn(
                        label: SizedBox(
                          width: 20,
                          child: Checkbox(
                            value: _selected.length == _files.length && _files.isNotEmpty,
                            tristate: true,
                            onChanged: (_) =>
                                _selected.length == _files.length ? _selectNone() : _selectAll(),
                          ),
                        ),
                      ),
                      DataColumn(label: Text('Filename', style: theme.textTheme.labelMedium)),
                      DataColumn(label: Text('Tracks', style: theme.textTheme.labelMedium), numeric: true),
                      DataColumn(label: Text('Size', style: theme.textTheme.labelMedium), numeric: true),
                      DataColumn(label: Text('Duration', style: theme.textTheme.labelMedium), numeric: true),
                    ],
                    rows: List.generate(_files.length, (i) {
                      final f = _files[i];
                      return DataRow(
                        selected: _selected.contains(i),
                        onSelectChanged: (val) {
                          if (_running) return;
                          setState(() {
                            if (val == true) {
                              _selected.add(i);
                            } else {
                              _selected.remove(i);
                            }
                          });
                        },
                        cells: [
                          DataCell(Transform.scale(
                            scale: 0.85,
                            child: Checkbox(
                              value: _selected.contains(i),
                              onChanged: (v) {
                                if (_running) return;
                                setState(() {
                                  if (v == true) {
                                    _selected.add(i);
                                  } else {
                                    _selected.remove(i);
                                  }
                                });
                              },
                            ),
                          )),
                          DataCell(Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.name,
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis),
                              if (f.trackCount > 0)
                                Text(
                                  f.tracks
                                      .map((t) =>
                                          't${t.index}: ${t.codec} ${t.channelsLabel} ${t.sampleRateLabel}')
                                      .join(' | '),
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          )),
                          DataCell(Text('${f.trackCount}')),
                          DataCell(Text(f.sizeLabel)),
                          DataCell(Text(f.durationLabel)),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Output Settings', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: _format,
                    decoration: const InputDecoration(
                        labelText: 'Format',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: ['aac', 'wav', 'flac']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f.toUpperCase())))
                        .toList(),
                    onChanged: _running
                        ? null
                        : (v) {
                            setState(() {
                              _format = v!;
                              if (v == 'wav' || v == 'flac') {
                                _bitrate = '-';
                              } else {
                                _bitrate = '384k';
                              }
                            });
                          },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    initialValue: _format == 'aac' ? _bitrate : null,
                    disabledHint: const Text('N/A'),
                    decoration: const InputDecoration(
                        labelText: 'Bitrate',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: ['128k', '192k', '256k', '320k', '384k', '512k']
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: _running || _format != 'aac'
                        ? null
                        : (v) => setState(() => _bitrate = v!),
                  ),
                ),
                const SizedBox(width: 12),
                ActionChip(
                  label: const Text('YouTube preset'),
                  avatar: const Icon(Icons.check_circle, size: 16),
                  onPressed: _running
                      ? null
                      : () => setState(() {
                            _format = 'aac';
                            _bitrate = '384k';
                          }),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Output: $_outputDir',
                      style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _running ? null : _pickOutput,
                  icon: const Icon(Icons.folder, size: 18),
                  label: const Text('Browse'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _running ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Extraction'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(ThemeData theme) {
    final pct = _progressTotal > 0 ? _progressDone / _progressTotal : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.downloading, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Progress', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (_running)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: pct),
            const SizedBox(height: 6),
            Text('$_progressDone / $_progressTotal tracks',
                style: theme.textTheme.bodySmall),
            if (_running) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _doCancel,
                  icon: const Icon(Icons.stop),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Log', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('${_logs.length} lines', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: ListView(
                controller: _logScroll,
                children: _logs.map((line) {
                  final isErr = line.contains('FAIL');
                  final isOk = line.contains('OK');
                  final isSkip = line.contains('SKIP');
                  Color? color;
                  if (isErr) {
                    color = theme.colorScheme.error;
                  } else if (isOk) {
                    color = Colors.green;
                  } else if (isSkip) {
                    color = theme.colorScheme.onSurfaceVariant;
                  }
                  return Text(line,
                      style: TextStyle(
                          fontFamily: 'monospace', fontSize: 11, color: color));
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

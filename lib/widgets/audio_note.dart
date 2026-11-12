import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'confirm_sheet.dart';

/// «0:18» — время заметки, как .audio-time в макете.
String formatAudioTime(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Потолок длины записи: 5 минут AAC 64 кбит/с — около 2,4 МБ, бекенд берёт до 10.
const maxAudioNote = Duration(minutes: 5);

/// .audio из макета: кнопка ▶/❚❚, волна и время.
///
/// Плеер создаётся по первому нажатию: в виджет-тестах платформенных каналов
/// нет, и плеер, созданный при сборке, уронил бы тест. Ссылка подписанная,
/// Bearer не нужен.
class AudioNotePlayer extends StatefulWidget {
  const AudioNotePlayer({
    super.key,
    required this.url,
    required this.seconds,
    required this.seed,
  });

  final String url;
  final int seconds;

  /// Форма волны: сервер её не отдаёт, рисуем стабильную от кода детали.
  final String seed;

  @override
  State<AudioNotePlayer> createState() => _AudioNotePlayerState();
}

class _AudioNotePlayerState extends State<AudioNotePlayer> {
  AudioPlayer? _player;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _playing = false;
  Duration _position = Duration.zero;

  Duration get _total => Duration(seconds: widget.seconds);

  @override
  void didUpdateWidget(AudioNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // заметку перезаписали — старая запись больше не играет
    if (oldWidget.url != widget.url) {
      _player?.stop();
      _playing = false;
      _position = Duration.zero;
    }
  }

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;

    final player = AudioPlayer();
    _subscriptions.addAll([
      player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
      // сбой нативного плеера (сеть, протухшая ссылка) приходит сюда
      // ошибкой потока, а не исключением из play()
      player.onPlayerStateChanged.listen(
        (s) {
          if (mounted) setState(() => _playing = s == PlayerState.playing);
        },
        onError: (Object _) => _failed(),
      ),
      player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _position = Duration.zero);
      }),
    ]);
    return _player = player;
  }

  Future<void> _toggle() async {
    final player = _ensurePlayer();
    try {
      if (_playing) {
        await player.pause();
      } else if (player.state == PlayerState.paused) {
        await player.resume();
      } else {
        // запись из очереди осмотра — ещё файл на телефоне
        await player.play(
          widget.url.startsWith('http')
              ? UrlSource(widget.url)
              : DeviceFileSource(widget.url),
        );
      }
    } catch (_) {
      _failed();
    }
  }

  void _failed() {
    if (!mounted) return;
    setState(() {
      _playing = false;
      _position = Duration.zero;
    });
    // плеер после ошибки не переиспользуем: следующее нажатие начнёт с нуля
    _player?.release();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось воспроизвести запись')),
    );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _total.inMilliseconds;
    final progress = totalMs == 0
        ? 0.0
        : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final shown = _playing || _position > Duration.zero ? _position : _total;

    return Row(
      children: [
        _RoundButton(
          icon: _playing ? Icons.pause : Icons.play_arrow,
          tooltip: _playing ? 'Пауза' : 'Слушать',
          onPressed: _toggle,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Wave(seed: widget.seed, progress: progress),
        ),
        const SizedBox(width: 12),
        Text(formatAudioTime(shown), style: _timeStyle(context)),
      ],
    );
  }
}

/// Секция «Голосовая заметка» на экране детали: запись, перезапись, удаление
/// и прослушивание. Колбэки сами показывают ошибки сервера и не бросают.
///
/// Экран даёт виджету ключ по коду детали: переход к следующей детали
/// пересоздаёт состояние, и незаконченная запись отменяется в [dispose].
class AudioNoteEditor extends StatefulWidget {
  const AudioNoteEditor({
    super.key,
    required this.seed,
    required this.url,
    required this.seconds,
    required this.readOnly,
    required this.onRecorded,
    required this.onDelete,
  });

  final String seed;
  final String? url;
  final int? seconds;
  final bool readOnly;
  final Future<void> Function(String filePath, int durationSeconds) onRecorded;
  final Future<void> Function() onDelete;

  @override
  State<AudioNoteEditor> createState() => _AudioNoteEditorState();
}

class _AudioNoteEditorState extends State<AudioNoteEditor> {
  AudioRecorder? _recorder;
  final _stopwatch = Stopwatch();
  Timer? _ticker;
  bool _recording = false;
  bool _busy = false;

  bool get _hasNote => widget.url != null && widget.seconds != null;

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _start() async {
    final recorder = _recorder ??= AudioRecorder();
    try {
      if (!await recorder.hasPermission()) {
        if (mounted) {
          _snack(
            'Нет доступа к микрофону — разрешите его в настройках телефона',
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/audio_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(bitRate: 64000, numChannels: 1),
        path: path,
      );
    } catch (_) {
      if (mounted) _snack('Не удалось начать запись');
      return;
    }
    if (!mounted) {
      await recorder.cancel();
      return;
    }

    _stopwatch
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_stopwatch.elapsed >= maxAudioNote) {
        _finish();
      } else if (mounted) {
        setState(() {});
      }
    });
    setState(() => _recording = true);
  }

  void _stopTicking() {
    _ticker?.cancel();
    _ticker = null;
    _stopwatch.stop();
  }

  Future<void> _cancel() async {
    _stopTicking();
    setState(() => _recording = false);
    await _recorder?.cancel();
  }

  Future<void> _finish() async {
    if (!_recording) return;
    _stopTicking();
    final seconds = _stopwatch.elapsed.inMilliseconds / 1000;
    setState(() {
      _recording = false;
      _busy = true;
    });

    String? path;
    try {
      path = await _recorder?.stop();
      if (path == null) {
        if (mounted) _snack('Не удалось сохранить запись');
        return;
      }
      if (seconds < 1) {
        if (mounted) _snack('Слишком коротко — запишите хотя бы секунду');
        return;
      }
      await widget.onRecorded(path, seconds.round());
    } finally {
      if (path != null) {
        File(path).delete().ignore();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Удалить заметку?',
      text: 'Запись к этой детали пропадёт из отчёта.',
      confirmLabel: 'Удалить',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.onDelete();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _stopTicking();
    final recorder = _recorder;
    if (recorder != null) {
      // ушли с детали посреди записи — запись не отправляем
      recorder.cancel().whenComplete(recorder.dispose).ignore();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        borderRadius: BorderRadius.circular(14),
      ),
      child: _recording
          ? _buildRecording(context)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_hasNote)
                  AudioNotePlayer(
                    url: widget.url!,
                    seconds: widget.seconds!,
                    seed: widget.seed,
                  )
                else
                  Text(
                    'нет записи',
                    style: TextStyle(color: context.colors.text3, fontSize: 12),
                  ),
                if (!widget.readOnly) ...[
                  const SizedBox(height: 12),
                  _buildActions(context),
                ],
              ],
            ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (_busy) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.mic_none,
            label: _hasNote ? 'Перезаписать' : 'Записать',
            onPressed: _start,
          ),
        ),
        if (_hasNote) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.delete_outline,
              label: 'Удалить',
              onPressed: _delete,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecording(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: context.colors.statusDefect,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(formatAudioTime(_stopwatch.elapsed), style: _timeStyle(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'идёт запись',
            style: TextStyle(color: context.colors.text2, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: _cancel,
          style: TextButton.styleFrom(foregroundColor: context.colors.text2),
          child: const Text('Отмена'),
        ),
        const SizedBox(width: 4),
        _RoundButton(icon: Icons.stop, tooltip: 'Готово', onPressed: _finish),
      ],
    );
  }
}

TextStyle _timeStyle(BuildContext context) => TextStyle(
  fontFamily: AppTheme.monoFamily,
  fontSize: 12,
  color: context.colors.text2,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// .audio-play: круглая кнопка 42px.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size(42, 42),
        backgroundColor: context.colors.text1,
        foregroundColor: context.colors.bg0,
        shape: const CircleBorder(),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.colors.text1,
        side: BorderSide(color: context.colors.line),
        padding: const EdgeInsets.symmetric(vertical: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    );
  }
}

/// .wave: столбики 2px, проигранные — text1, остальные — text3.
class _Wave extends StatelessWidget {
  const _Wave({required this.seed, required this.progress});

  final String seed;
  final double progress;

  static const _bars = 32;

  @override
  Widget build(BuildContext context) {
    // свой простой генератор: String.hashCode не обязан быть стабильным
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final played = (progress * _bars).round();

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          for (var i = 0; i < _bars; i++)
            Expanded(
              child: Center(
                child: Container(
                  width: 2,
                  height: (6 + ((h >> (i % 24)) + i * 7) % 22).toDouble(),
                  decoration: BoxDecoration(
                    color: i < played
                        ? context.colors.text1
                        : context.colors.text3,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

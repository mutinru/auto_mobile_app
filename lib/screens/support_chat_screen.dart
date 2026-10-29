import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_message.dart';
import '../state/chat_store.dart';
import '../theme/app_colors.dart';
import '../util/ru_date.dart';
import '../widgets/app_ui.dart';

/// Чат с поддержкой. Макета в design/ нет — собран из токенов и блоков
/// app_ui. Стор создаёт вызывающий код (не в builder маршрута), экран его
/// открывает и закрывает: опрос новых сообщений идёт, только пока экран
/// на виду.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key, required this.store});

  final ChatStore store;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> with WidgetsBindingObserver {
  /// Ограничения бекенда: до 5 фото и 4000 символов на сообщение.
  static const _maxPhotos = 5;
  static const _maxLength = 4000;

  final _text = TextEditingController();
  final _scroll = ScrollController();
  final List<String> _photos = [];

  ChatStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _text.addListener(() => setState(() {}));
    _store.open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _text.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _store.resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _store.pause();
    }
  }

  /// Список развёрнут (reverse) — история сверху, у maxScrollExtent.
  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _store.loadOlder();
    }
  }

  Future<void> _pickPhotos() async {
    final left = _maxPhotos - _photos.length;
    if (left <= 0) return;
    final picked = await ImagePicker().pickMultiImage(
      limit: left,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() => _photos.addAll(picked.take(left).map((f) => f.path)));
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _store.send(_text.text, List.of(_photos));
    if (!mounted) return;
    if (ok) {
      _text.clear();
      setState(_photos.clear);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else if (_store.sendError != null) {
      messenger.showSnackBar(SnackBar(content: Text(_store.sendError!)));
    }
  }

  bool get _canSend =>
      !_store.isSending && _store.conversation != null && (_text.text.trim().isNotEmpty || _photos.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) => Column(
            children: [
              DetailHead(
                title: 'Поддержка',
                eyebrow: 'отвечаем в среднем за 5 минут',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(child: _body()),
              if (_store.conversation != null) _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final c = context.colors;
    if (_store.isLoading && _store.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_store.error != null && _store.messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Не удалось открыть чат', style: TextStyle(fontSize: 14, color: c.text1)),
            const SizedBox(height: 6),
            Text(
              _store.error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: c.text3),
            ),
            const SizedBox(height: 10),
            CtaGhost(label: 'Повторить', onPressed: _store.open),
          ],
        ),
      );
    }
    if (_store.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Напишите, что случилось — ответим здесь же',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.text2, height: 1.45),
          ),
        ),
      );
    }

    // reverse: свежие снизу, клавиатура не уводит их из виду
    final items = _store.messages.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: items.length + (_store.isLoadingOlder ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == items.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final message = items[i];
        // соседи в хронологическом порядке: older — выше на экране
        final older = i + 1 < items.length ? items[i + 1] : null;
        final newDay = older == null || !_sameDay(older.createdAt, message.createdAt);
        final showName = !message.isMine && !message.isSystem && (newDay || older.isMine || older.isSystem);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newDay) _DaySeparator(chatDay(message.createdAt)),
            _MessageBubble(
              message: message,
              showName: showName,
              headers: _store.repository.imageHeaders,
            ),
          ],
        );
      },
    );
  }

  Widget _composer() {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bg0,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_photos.isNotEmpty)
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _PickedPhoto(
                  path: _photos[i],
                  onRemove: _store.isSending ? null : () => setState(() => _photos.removeAt(i)),
                ),
              ),
            ),
          if (_photos.isNotEmpty) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SquareIconButton(
                icon: Icons.photo_outlined,
                onTap: _store.isSending || _photos.length >= _maxPhotos ? () {} : _pickPhotos,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: _maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 14, color: c.text1),
                  decoration: InputDecoration(
                    hintText: 'Сообщение',
                    hintStyle: TextStyle(fontSize: 14, color: c.text3),
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: c.bg1,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: c.statusInfo),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                busy: _store.isSending,
                onTap: _canSend ? _send : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(label, style: TextStyle(fontSize: 11, color: context.colors.text3)),
      ),
    );
  }
}

/// Пузырь: моё — справа на акценте, поддержка — слева на bg1,
/// системное — строкой по центру.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.showName, required this.headers});

  final ChatMessage message;
  final bool showName;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        child: Text(
          message.body ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: c.text3, height: 1.4),
        ),
      );
    }

    final mine = message.isMine;
    final ink = mine ? c.infoInk : c.text1;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 4),
      bottomRight: Radius.circular(mine ? 4 : 16),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showName && message.senderName != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3, top: 4),
                  child: Text(
                    message.senderName!,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.text2),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: mine ? c.statusInfo : c.bg1,
                  border: mine ? null : Border.all(color: c.line),
                  borderRadius: radius,
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in message.attachments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _AttachmentThumb(attachment: a, headers: headers),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 8,
                        children: [
                          if (message.body != null && message.body!.isNotEmpty)
                            Text(message.body!, style: TextStyle(fontSize: 14, color: ink, height: 1.35)),
                          Text(
                            hhmm(message.createdAt),
                            style: TextStyle(fontSize: 10, color: ink.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Превью фото в пузыре; тап — во весь экран. Файл приватный, поэтому
/// с заголовками авторизации.
class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.attachment, required this.headers});

  final ChatAttachment attachment;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _PhotoViewer(url: attachment.url, headers: headers),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: attachment.aspectRatio.clamp(0.6, 1.8),
          child: Image.network(
            attachment.url,
            headers: headers,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: c.bg2,
              child: Icon(Icons.broken_image_outlined, color: c.text3),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(title: 'Фото', onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: Image.network(url, headers: headers)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickedPhoto extends StatelessWidget {
  const _PickedPhoto({required this.path, required this.onRemove});

  final String path;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(File(path), width: 64, height: 64, fit: BoxFit.cover),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: c.bg3,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.bg0, width: 2),
                ),
                child: Icon(Icons.close, size: 12, color: c.text1),
              ),
            ),
          ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = onTap != null;
    return Material(
      color: active ? c.statusInfo : c.bg3,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: busy
              ? Padding(
                  padding: const EdgeInsets.all(11),
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.text2),
                )
              : Icon(Icons.arrow_upward, size: 20, color: active ? c.infoInk : c.text3),
        ),
      ),
    );
  }
}

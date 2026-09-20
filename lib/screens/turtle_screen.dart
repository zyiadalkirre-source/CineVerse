import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/turtle_brain.dart';
import '../services/turtle_model_downloader.dart';

class TurtleScreen extends StatefulWidget {
  const TurtleScreen({super.key});

  @override
  State<TurtleScreen> createState() => _TurtleScreenState();
}

class _TurtleScreenState extends State<TurtleScreen> {
  static const _modelKey = 'turtle_model_path';
  static const _backendKey = 'turtle_backend';

  final TurtleBrain _brain = TurtleBrain();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_TurtleMessage> _messages = [];

  String? _modelPath;
  String _backend = 'cpu';
  bool _loadingModel = false;
  bool _generating = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _modelPath = prefs.getString(_modelKey);
      _backend = prefs.getString(_backendKey) ?? 'cpu';
    });

    if (_modelPath != null) {
      try {
        await _loadModel(showMessage: false);
      } catch (_) {
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _pickModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['litertlm'],
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, path);
    if (!mounted) return;
    setState(() => _modelPath = path);
    await _loadModel();
  }

  Future<void> _downloadModel() async {
    if (_loadingModel) return;

    setState(() {
      _loadingModel = true;
      _downloadProgress = 0;
    });

    try {
      final path = await TurtleModelDownloader.download(
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelKey, path);

      if (!mounted) return;
      setState(() {
        _modelPath = path;
        _downloadProgress = 1;
      });

      await _loadModel();
    } catch (e) {
      if (mounted) {
        _addAssistant(
          'تعذر تنزيل نموذج Turtle. تحقق من اتصال الإنترنت ثم حاول مرة أخرى، '
          'أو استخدم زر اختيار ملف لإدخال نموذج .litertlm موجود مسبقاً.',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ تنزيل نموذج Turtle: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingModel = false;
          _downloadProgress = 0;
        });
      }
    }
  }
  Future<void> _loadModel({bool showMessage = true}) async {
    final path = _modelPath;
    if (path == null || path.isEmpty) return;

    setState(() => _loadingModel = true);
    try {
      final backend = _backend == 'gpu'
          ? LiteLmBackend.gpu
          : _backend == 'npu'
              ? LiteLmBackend.npu
              : LiteLmBackend.cpu;
      await _brain.load(modelPath: path, backend: backend);
      if (showMessage && mounted) {
        _addAssistant('🐢 Turtle جاهز. المحادثة الآن تعمل محلياً على جهازك.');
      }
    } catch (e) {
      if (mounted) {
        _addAssistant(
          'تعذر تحميل النموذج. تأكد أن الملف .litertlm صالح '
          'وأن جهازك يدعم الـBackend المختار.',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ تحميل النموذج: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingModel = false);
    }
  }

  Future<void> _selectBackend(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendKey, value);
    setState(() => _backend = value);
    if (_modelPath != null) await _loadModel();
  }

  Future<void> _send() async {
    final prompt = _input.text.trim();
    if (prompt.isEmpty || _generating) return;

    if (!_brain.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر أو حمّل نموذج Turtle أولاً.')),
      );
      return;
    }

    _input.clear();
    _messages.add(_TurtleMessage(prompt, true));
    setState(() => _generating = true);
    _scrollToBottom();

    final assistantIndex = _messages.length;
    _messages.add(const _TurtleMessage('', false));
    var buffer = StringBuffer();

    try {
      await for (final delta in _brain.askStream(prompt)) {
        buffer.write(delta);
        _messages[assistantIndex] = _TurtleMessage(buffer.toString(), false);
        if (mounted) setState(() {});
        _scrollToBottom();
      }
    } catch (e) {
      _messages[assistantIndex] =
          _TurtleMessage('حدث خطأ أثناء التوليد المحلي: $e', false);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _addAssistant(String text) {
    _messages.add(_TurtleMessage(text, false));
    setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _brain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _brain.isReady;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐢 Turtle'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _backend,
            onSelected: _selectBackend,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'cpu', child: Text('CPU — متوافق')),
              PopupMenuItem(value: 'gpu', child: Text('GPU — Android')),
              PopupMenuItem(value: 'npu', child: Text('NPU — إن كان مدعوماً')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _TurtleStatus(
            ready: ready,
            loading: _loadingModel,
            modelPath: _modelPath,
            downloadProgress: _downloadProgress,
            onDownload: _downloadModel,
            onPick: _pickModel,
          ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '🐢\n\nأنا Turtle، مساعد محلي.\n'
                        'حمّل النموذج المقترح أو اختر ملف .litertlm من الجهاز.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, index) =>
                        _TurtleBubble(message: _messages[index]),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      enabled: ready && !_generating,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: ready ? 'اكتب لـ Turtle...' : 'حمّل النموذج أولاً',
                        prefixIcon: const Icon(Icons.terminal),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: ready && !_generating ? _send : null,
                    icon: _generating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurtleStatus extends StatelessWidget {
  final bool ready;
  final bool loading;
  final String? modelPath;
  final double downloadProgress;
  final VoidCallback onDownload;
  final VoidCallback onPick;

  const _TurtleStatus({
    required this.ready,
    required this.loading,
    required this.modelPath,
    required this.downloadProgress,
    required this.onDownload,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final hasProgress = loading && downloadProgress > 0;
    final percent = (downloadProgress * 100).round();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Text('🐢')),
              title: Text(
                loading && !hasProgress
                    ? 'جاري تجهيز Turtle...'
                    : ready
                        ? 'Turtle يعمل محلياً'
                        : 'Turtle غير مُجهّز',
              ),
              subtitle: Text(
                modelPath == null
                    ? 'لا يوجد نموذج حالياً. النموذج المقترح حوالي 329 MiB.'
                    : modelPath!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasProgress) ...[
              LinearProgressIndicator(value: downloadProgress),
              const SizedBox(height: 6),
              Text('جاري تنزيل النموذج: $percent%'),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: loading ? null : onDownload,
                  icon: const Icon(Icons.download),
                  label: Text(
                    ready ? 'إعادة تنزيل النموذج' : 'تحميل النموذج',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: loading ? null : onPick,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('اختيار ملف'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'النموذج يعمل على الجهاز بدون إرسال المحادثة إلى الإنترنت.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TurtleBubble extends StatelessWidget {
  final _TurtleMessage message;
  const _TurtleBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .82,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? scheme.primaryContainer : scheme.secondaryContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 20),
          ),
          border: Border.all(
            color: isUser ? scheme.primary : scheme.secondary,
            width: 1,
          ),
        ),
        child: Text(
          message.text.isEmpty && !isUser ? '🐢 يفكر...' : message.text,
        ),
      ),
    );
  }
}

class _TurtleMessage {
  final String text;
  final bool isUser;
  const _TurtleMessage(this.text, this.isUser);
}
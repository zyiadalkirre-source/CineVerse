import 'dart:async';
import 'package:flutter_litert_lm/flutter_litert_lm.dart';

/// Local-only LLM engine for Turtle.
///
/// The model file is selected by the user and stays on the device.
/// No API key or remote inference service is used here.
class TurtleBrain {
  LiteLmEngine? _engine;
  LiteLmConversation? _conversation;

  bool get isReady => _conversation != null;

  Future<void> load({
    required String modelPath,
    LiteLmBackend backend = LiteLmBackend.cpu,
  }) async {
    await dispose();

    _engine = await LiteLmEngine.create(
      LiteLmEngineConfig(
        modelPath: modelPath,
        backend: backend,
      ),
    );

    _conversation = await _engine!.createConversation(
      LiteLmConversationConfig(
        systemInstruction:
            'You are Turtle, a private on-device assistant. '
            'Answer clearly and helpfully. Match the user language. '
            'Do not claim to have internet access or remote tools unless they are actually available.',
        samplerConfig: const LiteLmSamplerConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
        ),
      ),
    );
  }

  Future<String> ask(String prompt) async {
    final conversation = _conversation;
    if (conversation == null) {
      throw StateError('Turtle model is not loaded.');
    }
    final reply = await conversation.sendMessage(prompt);
    return reply.text;
  }

  Stream<String> askStream(String prompt) async* {
    final conversation = _conversation;
    if (conversation == null) {
      throw StateError('Turtle model is not loaded.');
    }

    await for (final delta in conversation.sendMessageStream(prompt)) {
      yield delta.text;
    }
  }

  Future<void> dispose() async {
    final conversation = _conversation;
    _conversation = null;
    if (conversation != null) {
      await conversation.dispose();
    }

    final engine = _engine;
    _engine = null;
    if (engine != null) {
      await engine.dispose();
    }
  }
}

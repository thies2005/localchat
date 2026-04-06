import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gemini_nano_android/gemini_nano_android.dart';
import '../models/chat_message.dart';
import 'log_service.dart';

enum ModelStatus { checking, available, unavailable }

enum MultimodalStatus { unknown, supported, unsupported }

class AIService extends ChangeNotifier {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  final _gemini = GeminiNanoAndroid();
  final _log = LogService();
  ModelStatus _status = ModelStatus.checking;
  MultimodalStatus _multimodalStatus = MultimodalStatus.unknown;
  bool _isGenerating = false;

  static const int _maxContinueRounds = 4;

  ModelStatus get status => _status;
  bool get isGenerating => _isGenerating;
  MultimodalStatus get multimodalStatus => _multimodalStatus;

  Future<void> initialize() async {
    _status = ModelStatus.checking;
    notifyListeners();
    try {
      _log.info('AIService', 'Checking Gemini Nano availability...');
      final available = await _gemini.isAvailable();
      _status = available ? ModelStatus.available : ModelStatus.unavailable;
      _log.info(
          'AIService', 'isAvailable() = $available, status -> ${_status.name}');
    } catch (e, stackTrace) {
      _status = ModelStatus.unavailable;
      _log.error('AIService', 'ERROR checking availability: $e',
          error: e, stackTrace: stackTrace);
    }
    notifyListeners();
  }

  Future<String> sendMessage({
    required List<ChatMessage> history,
    required String input,
    Uint8List? imageBytes,
    double temperature = 0.7,
    int topK = 40,
    int maxOutputTokens = 256,
    bool autoContinue = true,
    Function(String)? onUpdate,
    Function(int tokenCount, double tokensPerSecond)? onStats,
  }) async {
    _isGenerating = true;
    notifyListeners();
    _log.info('AIService',
        'sendMessage | input: "$input" | hasImage: ${imageBytes != null} | history: ${history.length} | temp: $temperature | topK: $topK | maxTokens: $maxOutputTokens | autoContinue: $autoContinue');
    try {
      if (imageBytes != null && _multimodalStatus == MultimodalStatus.unknown) {
        await _probeMultimodalSupport(imageBytes);
      }

      if (imageBytes != null &&
          _multimodalStatus == MultimodalStatus.unsupported) {
        _log.warning(
            'AIService', 'Multimodal not supported, sending text only');
        imageBytes = null;
      }

      final prompt = _buildPrompt(history, input);
      _log.info('AIService',
          'Prompt built (${prompt.length} chars), calling _gemini.generate()...');

      final totalStopwatch = Stopwatch()..start();
      String fullResponse = '';
      final initialResults = await _gemini.generate(
        prompt: prompt,
        image: imageBytes,
        temperature: temperature,
        topK: topK,
        maxOutputTokens: maxOutputTokens,
      );
      _log.info('AIService',
          'generate() returned ${initialResults.length} result(s)');
      if (initialResults.isEmpty) {
        _log.warning('AIService', 'generate() returned empty results');
        return "I couldn't generate a response. Please try again.";
      }
      fullResponse = initialResults.first.trim();
      _log.info('AIService', 'Initial response: ${fullResponse.length} chars');

      onUpdate?.call(fullResponse);

      if (autoContinue && _isTruncated(fullResponse)) {
        fullResponse = await _continueGenerating(
          fullResponse,
          maxOutputTokens: maxOutputTokens,
          temperature: temperature,
          topK: topK,
          onUpdate: onUpdate,
        );
      }

      totalStopwatch.stop();
      final tokenCount = _estimateTokens(fullResponse);
      final seconds = totalStopwatch.elapsedMilliseconds / 1000.0;
      final tokensPerSecond = seconds > 0 ? tokenCount / seconds : 0.0;
      _log.info('AIService',
          'Stats: $tokenCount tokens in ${seconds.toStringAsFixed(1)}s = ${tokensPerSecond.toStringAsFixed(1)} tok/s');
      onStats?.call(tokenCount, tokensPerSecond);

      return fullResponse;
    } catch (e, stackTrace) {
      _log.error('AIService', 'ERROR in sendMessage: $e',
          error: e, stackTrace: stackTrace);
      return "Something went wrong. Check logs for details.";
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> _probeMultimodalSupport(Uint8List imageBytes) async {
    _log.info('AIService', 'Probing multimodal support...');
    try {
      final results = await _gemini.generate(
        prompt: 'Describe what you see.',
        image: imageBytes,
        maxOutputTokens: 16,
      );
      if (results.isNotEmpty) {
        _multimodalStatus = MultimodalStatus.supported;
        _log.info('AIService', 'Multimodal is SUPPORTED');
      } else {
        _multimodalStatus = MultimodalStatus.unsupported;
        _log.warning('AIService', 'Multimodal probe returned empty');
      }
    } catch (e) {
      _multimodalStatus = MultimodalStatus.unsupported;
      _log.warning('AIService', 'Multimodal NOT supported: $e');
    }
    notifyListeners();
  }

  Future<String> _continueGenerating(
    String existingResponse, {
    required int maxOutputTokens,
    required double temperature,
    required int topK,
    Function(String)? onUpdate,
  }) async {
    _log.info('AIService', 'Response truncated, starting auto-continuation...');
    String fullResponse = existingResponse;

    for (int round = 1; round <= _maxContinueRounds; round++) {
      final continuationPrompt =
          '$fullResponse\n\nContinue exactly from where you left off. Do not repeat what was already said.';
      _log.info('AIService',
          'Continue round $round/$_maxContinueRounds (${continuationPrompt.length} chars)...');

      try {
        await Future.delayed(const Duration(milliseconds: 1500));

        List<String> results = [];
        try {
          results = await _gemini.generate(
            prompt: continuationPrompt,
            temperature: temperature,
            topK: topK,
            maxOutputTokens: maxOutputTokens,
          );
        } catch (e) {
          if (e.toString().contains('ErrorCode 9')) {
            _log.warning('AIService',
                'Quota exceeded in round $round, retrying once after 2s delay...');
            await Future.delayed(const Duration(milliseconds: 2000));
            results = await _gemini.generate(
              prompt: continuationPrompt,
              temperature: temperature,
              topK: topK,
              maxOutputTokens: maxOutputTokens,
            );
          } else {
            rethrow;
          }
        }

        if (results.isEmpty) {
          _log.warning(
              'AIService', 'Continue round $round: empty results, stopping');
          break;
        }

        final continuation = _stripPrefix(results.first.trim(), fullResponse);
        if (continuation.isEmpty) {
          _log.info('AIService',
              'Continue round $round: empty after stripping, stopping');
          break;
        }

        fullResponse = '$fullResponse\n$continuation';
        _log.info('AIService',
            'Continue round $round: +${continuation.length} chars (total: ${fullResponse.length})');

        onUpdate?.call(fullResponse);

        if (!_isTruncated(continuation)) {
          _log.info('AIService', 'Response complete after round $round');
          break;
        }
      } catch (e, stackTrace) {
        _log.error('AIService', 'Continue round $round error: $e',
            error: e, stackTrace: stackTrace);
        break;
      }
    }

    return fullResponse;
  }

  bool _isTruncated(String text) {
    if (text.length < 100) return false;
    final trimmed = text.trimRight();
    final lastChar = trimmed.isNotEmpty ? trimmed[trimmed.length - 1] : '';
    if ({'.', '!', '?', '"', "'", '}', ']', ')', ':', ';', '*'}
        .contains(lastChar)) {
      return false;
    }
    if (trimmed.endsWith('```') ||
        trimmed.endsWith('"""') ||
        trimmed.endsWith("'''")) {
      return false;
    }
    if (trimmed.contains('\n```') && !trimmed.endsWith('```')) {
      return true;
    }
    return true;
  }

  String _stripPrefix(String continuation, String existing) {
    final existingEnd = existing.length > 80
        ? existing.substring(existing.length - 80)
        : existing;
    if (continuation.startsWith(existingEnd)) {
      return continuation.substring(existingEnd.length).trim();
    }
    final words = existing.split(' ');
    if (words.length > 5) {
      final tail = words.sublist(words.length - 5).join(' ');
      if (continuation.startsWith(tail)) {
        return continuation.substring(tail.length).trim();
      }
    }
    if (continuation.startsWith('Continue') ||
        continuation.startsWith('Sure')) {
      final newlineIdx = continuation.indexOf('\n');
      if (newlineIdx != -1) {
        return continuation.substring(newlineIdx + 1).trim();
      }
    }
    return continuation;
  }

  String _buildPrompt(List<ChatMessage> history, String input) {
    final buffer = StringBuffer();
    final relevantHistory = <String>[];
    int charCount = 0;

    for (final msg in history.reversed) {
      String line;
      if (msg.imagePath.isNotEmpty) {
        line = "${msg.isUser ? 'User' : 'Assistant'}: [Image] ${msg.text}";
      } else {
        line = "${msg.isUser ? 'User' : 'Assistant'}: ${msg.text}";
      }
      if (charCount + line.length > 3000) break;
      relevantHistory.insert(0, line);
      charCount += line.length;
    }

    for (final line in relevantHistory) {
      buffer.writeln(line);
    }
    buffer.write("Assistant:");
    return buffer.toString();
  }

  int _estimateTokens(String text) {
    return (text.length / 3.5).round();
  }
}

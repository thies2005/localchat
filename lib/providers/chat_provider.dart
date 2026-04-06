import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';
import '../services/log_service.dart';
import 'settings_provider.dart';

class ChatProvider extends ChangeNotifier {
  final DatabaseService _db;
  final _log = LogService();
  List<Conversation> conversations = [];
  Conversation? activeConversation;
  List<ChatMessage> messages = [];

  ChatProvider(this._db);

  void loadConversations() {
    _log.info('ChatProvider', 'loadConversations()');
    conversations = _db.getAllConversations();
    _log.info('ChatProvider', 'Loaded ${conversations.length} conversation(s)');
    notifyListeners();
  }

  void newConversation() {
    final conversation = _db.createConversation('New Chat');
    conversations.insert(0, conversation);
    activeConversation = conversation;
    messages = [];
    _log.info('ChatProvider', 'Created new conversation id=${conversation.id}');
    notifyListeners();
  }

  void selectConversation(int conversationId) {
    final found = conversations.firstWhere(
      (c) => c.id == conversationId,
    );
    activeConversation = found;
    messages = _db.getMessages(conversationId);
    _log.info('ChatProvider',
        'Selected conversation id=$conversationId with ${messages.length} message(s)');
    notifyListeners();
  }

  Future<void> sendMessage(
    String text,
    AIService ai,
    SettingsProvider settings, {
    Uint8List? imageBytes,
    String? imagePath,
  }) async {
    if (activeConversation == null) {
      newConversation();
    }

    final lockedConversationId = activeConversation!.id;

    _log.info('ChatProvider',
        'sendMessage() | locked to conversation: $lockedConversationId | aiStatus: ${ai.status.name} | hasImage: ${imageBytes != null}');

    final userMessage = ChatMessage(
      conversationId: lockedConversationId,
      text: text,
      isUser: true,
      imagePath: imagePath ?? '',
    );
    _db.addMessage(userMessage);

    if (activeConversation?.id == lockedConversationId) {
      messages.add(userMessage);
    }

    if (conversations.indexOf(activeConversation!) != 0) {
      conversations.remove(activeConversation!);
      conversations.insert(0, activeConversation!);
    }
    _db.updateConversationUpdatedAt(lockedConversationId);

    final userMessagesInConversation = messages.where((m) => m.isUser).length;
    if (userMessagesInConversation == 1) {
      final title = imagePath != null
          ? 'Image message'
          : (text.length > 40 ? '${text.substring(0, 40)}...' : text);
      _db.updateConversationTitle(lockedConversationId, title);
      activeConversation!.title = title;
    }

    notifyListeners();

    final aiMessage = ChatMessage(
      conversationId: lockedConversationId,
      text: '',
      isUser: false,
    );
    _db.addMessage(aiMessage);

    if (activeConversation?.id == lockedConversationId) {
      messages.add(aiMessage);
    }
    notifyListeners();

    try {
      final historyForPrompt =
          messages.where((m) => m.id != aiMessage.id).toList();
      _log.info('ChatProvider',
          'Calling ai.sendMessage() with ${historyForPrompt.length} messages for prompt...');

      final response = await ai.sendMessage(
        history: historyForPrompt,
        input: text,
        imageBytes: imageBytes,
        temperature: settings.temperature,
        topK: settings.topK,
        maxOutputTokens: settings.maxOutputTokens,
        autoContinue: settings.autoContinue,
        onUpdate: (partialText) {
          aiMessage.text = partialText;
          _db.updateMessage(aiMessage);
          notifyListeners();
        },
        onStats: (tokenCount, tokensPerSecond) {
          aiMessage.tokenCount = tokenCount;
          aiMessage.tokensPerSecond = tokensPerSecond;
          _db.updateMessage(aiMessage);
          notifyListeners();
        },
      );

      _log.info('ChatProvider',
          'AI responded (${response.length} chars) for conversation $lockedConversationId');

      aiMessage.text = response;
      _db.updateMessage(aiMessage);
      _db.updateConversationUpdatedAt(lockedConversationId);
    } catch (e, stackTrace) {
      _log.error('ChatProvider', 'ERROR during message flow: $e',
          error: e, stackTrace: stackTrace);
    }

    notifyListeners();
  }

  void deleteConversation(int conversationId) {
    _db.deleteConversation(conversationId);
    conversations.removeWhere((c) => c.id == conversationId);
    if (activeConversation?.id == conversationId) {
      activeConversation =
          conversations.isNotEmpty ? conversations.first : null;
      messages = activeConversation != null
          ? _db.getMessages(activeConversation!.id)
          : [];
    }
    notifyListeners();
  }
}

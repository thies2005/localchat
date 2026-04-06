import 'dart:math';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/conversation.dart';
import '../models/chat_message.dart';
import 'log_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Isar _isar;
  bool _initialized = false;
  int _conversationIdCounter = 1;
  int _messageIdCounter = 1;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    LogService().info('DatabaseService', 'Opening Isar at ${dir.path}');
    _isar = await Isar.open(
      schemas: [ConversationSchema, ChatMessageSchema],
      directory: dir.path,
    );
    _initialized = true;
    _restoreCounters();
    LogService().info('DatabaseService',
        'Isar opened | nextConvId: $_conversationIdCounter | nextMsgId: $_messageIdCounter');
  }

  void _restoreCounters() {
    final convs = _isar.conversations.where().sortByIdDesc().findAll();
    if (convs.isNotEmpty) {
      _conversationIdCounter = convs.map((c) => c.id).reduce(max) + 1;
    }
    final msgs = _isar.chatMessages.where().sortByIdDesc().findAll();
    if (msgs.isNotEmpty) {
      _messageIdCounter = msgs.map((m) => m.id).reduce(max) + 1;
    }
  }

  List<Conversation> getAllConversations() {
    return _isar.conversations.where().sortByUpdatedAtDesc().findAll();
  }

  Conversation createConversation(String title) {
    final id = _conversationIdCounter++;
    final conversation = Conversation(id: id, title: title);
    _isar.write((isar) {
      isar.conversations.put(conversation);
    });
    LogService().info('DatabaseService', 'Created conversation id=$id');
    return conversation;
  }

  void updateConversationTitle(int id, String title) {
    _isar.write((isar) {
      final conversation = isar.conversations.get(id);
      if (conversation != null) {
        conversation.title = title;
        conversation.updatedAt = DateTime.now();
        isar.conversations.put(conversation);
      }
    });
  }

  void updateConversationUpdatedAt(int id) {
    _isar.write((isar) {
      final conversation = isar.conversations.get(id);
      if (conversation != null) {
        conversation.updatedAt = DateTime.now();
        isar.conversations.put(conversation);
      }
    });
  }

  void deleteConversation(int id) {
    _isar.write((isar) {
      isar.chatMessages.where().conversationIdEqualTo(id).deleteAll();
      isar.conversations.delete(id);
    });
    LogService().info('DatabaseService', 'Deleted conversation id=$id');
  }

  List<ChatMessage> getMessages(int conversationId) {
    return _isar.chatMessages
        .where()
        .conversationIdEqualTo(conversationId)
        .sortByTimestamp()
        .findAll();
  }

  void addMessage(ChatMessage message) {
    final id = _messageIdCounter++;
    message.id = id;
    _isar.write((isar) {
      isar.chatMessages.put(message);
    });
  }

  void updateMessage(ChatMessage message) {
    _isar.write((isar) {
      isar.chatMessages.put(message);
    });
  }

  void deleteMessagesForConversation(int conversationId) {
    _isar.write((isar) {
      isar.chatMessages
          .where()
          .conversationIdEqualTo(conversationId)
          .deleteAll();
    });
  }
}

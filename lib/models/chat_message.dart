import 'package:isar/isar.dart';

part 'chat_message.g.dart';

@collection
class ChatMessage {
  int id;

  @index
  int conversationId;

  String text;

  bool isUser;

  DateTime timestamp = DateTime.now();

  int tokenCount = 0;

  double tokensPerSecond = 0;

  String imagePath = '';

  ChatMessage({
    this.id = 0,
    this.conversationId = 0,
    this.text = '',
    this.isUser = false,
    this.tokenCount = 0,
    this.tokensPerSecond = 0,
    this.imagePath = '',
  });
}

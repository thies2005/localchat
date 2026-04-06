import 'package:isar/isar.dart';

part 'conversation.g.dart';

@collection
class Conversation {
  int id;

  String title;

  DateTime createdAt = DateTime.now();

  DateTime updatedAt = DateTime.now();

  Conversation({
    this.id = 0,
    this.title = 'New Chat',
  });
}

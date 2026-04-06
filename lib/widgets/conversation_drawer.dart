import 'package:flutter/material.dart';
import '../models/conversation.dart';

class ConversationDrawer extends StatelessWidget {
  final List<Conversation> conversations;
  final int? activeConversationId;
  final Function(int) onSelect;
  final Function() onNewChat;
  final Function(int) onDelete;

  const ConversationDrawer({
    super.key,
    required this.conversations,
    this.activeConversationId,
    required this.onSelect,
    required this.onNewChat,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNewChat,
                  icon: const Icon(Icons.add),
                  label: const Text('New Chat'),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Start a new chat',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final isActive =
                            conversation.id == activeConversationId;

                        return Dismissible(
                          key: ValueKey(conversation.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            color: colorScheme.error,
                            child:
                                Icon(Icons.delete, color: colorScheme.onError),
                          ),
                          onDismissed: (_) => onDelete(conversation.id),
                          child: ListTile(
                            selected: isActive,
                            selectedTileColor: colorScheme.secondaryContainer,
                            selectedColor: colorScheme.onSecondaryContainer,
                            leading: const Icon(Icons.chat_outlined),
                            title: Text(
                              conversation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _formatRelativeTime(conversation.updatedAt),
                              style: theme.textTheme.labelSmall,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => onDelete(conversation.id),
                            ),
                            onTap: () {
                              onSelect(conversation.id);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.month}/${time.day}';
  }
}

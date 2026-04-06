import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/message_input.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/status_banner.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/log_viewer_sheet.dart';
import '../widgets/context_diagram_sheet.dart';

class ChatScreen extends StatelessWidget {
  ChatScreen({super.key});

  final _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ai = context.watch<AIService>();
    final chat = context.watch<ChatProvider>();
    final settings = context.watch<SettingsProvider>();

    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('LocalChat'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Powered by Gemini Nano · On-Device',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Architecture',
            onPressed: () => ContextDiagramSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'View Logs',
            onPressed: () => LogViewerSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => SettingsSheet.show(context),
          ),
        ],
      ),
      drawer: ConversationDrawer(
        conversations: chat.conversations,
        activeConversationId: chat.activeConversation?.id,
        onSelect: (id) => chat.selectConversation(id),
        onNewChat: () => chat.newConversation(),
        onDelete: (id) => chat.deleteConversation(id),
      ),
      body: Column(
        children: [
          StatusBanner(status: ai.status),
          Expanded(
            child: chat.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Hi! I\'m running entirely on your device. Your conversations are private and never leave this phone.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          chat.messages[chat.messages.length - 1 - index];
                      final isLastAiMessage = !message.isUser && index == 0;
                      return ChatBubble(
                        key: ValueKey(message.id),
                        message: message,
                        animate: isLastAiMessage,
                        isStreaming: ai.isGenerating && isLastAiMessage,
                        showTokenStats: settings.showTokenStats,
                      );
                    },
                  ),
          ),
          if (ai.isGenerating)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TypingIndicator(),
            ),
          MessageInput(
            isEnabled: ai.status == ModelStatus.available,
            isGenerating: ai.isGenerating,
            onSend: (text, {imageBytes, imagePath}) => chat.sendMessage(
              text,
              ai,
              settings,
              imageBytes: imageBytes,
              imagePath: imagePath,
            ),
          ),
        ],
      ),
    );
  }
}

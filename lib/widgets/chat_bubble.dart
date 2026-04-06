import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final bool animate;
  final bool isStreaming;
  final bool showTokenStats;

  const ChatBubble({
    super.key,
    required this.message,
    this.animate = false,
    this.isStreaming = false,
    this.showTokenStats = true,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  String _displayedText = '';
  Timer? _streamTimer;
  Timer? _cursorTimer;
  bool _showCursor = true;
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _entryController.forward();

    if (widget.animate && !widget.message.isUser) {
      _startStreaming();
    } else {
      _displayedText = widget.message.text;
    }
  }

  @override
  void didUpdateWidget(ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.message.id != widget.message.id) {
      _streamTimer?.cancel();
      _cursorTimer?.cancel();
      if (widget.animate && !widget.message.isUser) {
        _startStreaming();
      } else {
        _displayedText = widget.message.text;
        _showCursor = false;
      }
      return;
    }

    if (oldWidget.isStreaming && !widget.isStreaming) {
      _displayedText = widget.message.text;
      if (mounted) setState(() {});
    }

    if (!widget.isStreaming) {
      if (_displayedText != widget.message.text) {
        _displayedText = widget.message.text;
        if (mounted) setState(() {});
      }
      _cursorTimer?.cancel();
      _showCursor = false;
    }
  }

  void _startStreaming() {
    _charIndex = 0;
    _displayedText = '';
    _startCursorBlink();
    _streamTimer?.cancel();

    _streamTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      final currentFullText = widget.message.text;
      if (_charIndex >= currentFullText.length) {
        if (!widget.isStreaming) {
          timer.cancel();
          _cursorTimer?.cancel();
          _showCursor = false;
          if (mounted) setState(() => _displayedText = currentFullText);
        }
        return;
      }
      final chunkSize = (currentFullText.length - _charIndex).clamp(1, 4);
      if (mounted) {
        setState(() {
          _charIndex += chunkSize;
          _displayedText = currentFullText.substring(0, _charIndex);
        });
      }
    });
  }

  void _startCursorBlink() {
    _cursorTimer?.cancel();
    _showCursor = true;
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 530), (timer) {
      if (mounted) {
        setState(() => _showCursor = !_showCursor);
      }
    });
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _cursorTimer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = widget.message.isUser;

    final backgroundColor =
        isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final textColor = isUser ? colorScheme.onPrimary : colorScheme.onSurface;

    final isCurrentlyStreaming =
        widget.isStreaming && !isUser && _displayedText != widget.message.text;

    return FadeTransition(
      opacity: _entryController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(isUser ? 0.3 : -0.3, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _entryController,
          curve: Curves.easeOutCubic,
        )),
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Material(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  color: backgroundColor,
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.message.imagePath.isNotEmpty)
                          _buildImage(widget.message.imagePath),
                        if (widget.message.imagePath.isNotEmpty &&
                            widget.message.text.isNotEmpty)
                          const SizedBox(height: 8),
                        if (widget.message.text.isNotEmpty)
                          isUser
                              ? SelectableText(
                                  _displayedText,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: textColor,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MarkdownBody(
                                      data: _displayedText,
                                      selectable: true,
                                      styleSheet:
                                          MarkdownStyleSheet.fromTheme(theme)
                                              .copyWith(
                                        p: theme.textTheme.bodyLarge?.copyWith(
                                          color: textColor,
                                          height: 1.5,
                                        ),
                                        code: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: textColor,
                                          backgroundColor:
                                              colorScheme.surfaceContainerHigh,
                                          fontFamily: 'monospace',
                                        ),
                                        codeblockDecoration: BoxDecoration(
                                          color:
                                              colorScheme.surfaceContainerHigh,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        blockquoteDecoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: colorScheme.primary,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        h1: theme.textTheme.titleLarge
                                            ?.copyWith(color: textColor),
                                        h2: theme.textTheme.titleMedium
                                            ?.copyWith(color: textColor),
                                        h3: theme.textTheme.titleSmall
                                            ?.copyWith(color: textColor),
                                        a: TextStyle(
                                          color: colorScheme.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                        listBullet: TextStyle(color: textColor),
                                        tableHead: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        tableBorder: TableBorder.all(
                                          color: colorScheme.outlineVariant,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                    if (_showCursor && isCurrentlyStreaming)
                                      Container(
                                        width: 2,
                                        height: 16,
                                        color: textColor,
                                        margin: const EdgeInsets.only(top: 2),
                                      ),
                                  ],
                                ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(widget.message.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isCurrentlyStreaming) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Generating...',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (!isUser && !isCurrentlyStreaming) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.message.text),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Copied to clipboard'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (widget.showTokenStats &&
                            widget.message.tokenCount > 0) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.bolt_outlined,
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${widget.message.tokenCount} tok',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.message.tokensPerSecond.toStringAsFixed(1)} tok/s',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    return FutureBuilder<bool>(
      future: File(imagePath).exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            width: 200,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.data != true) {
          return const SizedBox.shrink();
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            width: 200,
            height: 120,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

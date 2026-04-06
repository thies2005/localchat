import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';

class LogViewerSheet {
  static void show(BuildContext context) {
    final log = LogService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _LogViewer(log: log),
    );
  }
}

class _LogViewer extends StatefulWidget {
  final LogService log;
  const _LogViewer({required this.log});

  @override
  State<_LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<_LogViewer> {
  late List<LogEntry> _entries;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _entries = widget.log.entries;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _levelColor(String level, ColorScheme colors) {
    return switch (level) {
      'ERROR' => colors.error,
      'WARN' => Colors.orange,
      _ => colors.onSurface,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.bug_report, color: colorScheme.onSurface),
                  const SizedBox(width: 12),
                  Text(
                    'App Logs (${_entries.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.log.getFullLog()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logs copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy All'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () {
                      widget.log.clear();
                      setState(() => _entries = []);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Clear'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _entries.isEmpty
                  ? Center(
                      child: Text(
                        'No logs yet. Send a message to generate logs.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectionArea(
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        '${entry.timestamp.toIso8601String().substring(11, 23)} ',
                                    style: TextStyle(
                                        color: colorScheme.onSurfaceVariant),
                                  ),
                                  TextSpan(
                                    text: '[${entry.level}] ',
                                    style: TextStyle(
                                      color:
                                          _levelColor(entry.level, colorScheme),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '[${entry.tag}] ',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: entry.message,
                                    style:
                                        TextStyle(color: colorScheme.onSurface),
                                  ),
                                  if (entry.error != null) ...[
                                    const TextSpan(text: '\n  '),
                                    TextSpan(
                                      text: entry.error!,
                                      style:
                                          TextStyle(color: colorScheme.error),
                                    ),
                                  ],
                                  if (entry.stackTrace != null) ...[
                                    const TextSpan(text: '\n  '),
                                    TextSpan(
                                      text: entry.stackTrace!,
                                      style: TextStyle(
                                        color:
                                            colorScheme.error.withOpacity(0.7),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

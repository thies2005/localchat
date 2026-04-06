import 'package:flutter/material.dart';

class ContextDiagramSheet {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ContextDiagramSheet(),
    );
  }
}

class _ContextDiagramSheet extends StatelessWidget {
  const _ContextDiagramSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Architecture Overview',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'LocalChat uses Gemini Nano on-device AI via Android AICore. All processing happens locally on your phone.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              _buildDiagram(context, colorScheme),
              const SizedBox(height: 32),
              _buildLegend(context, colorScheme),
              const SizedBox(height: 24),
              _buildFlowSteps(context, colorScheme),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagram(BuildContext context, ColorScheme colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final boxW = w * 0.3;
        final arrowW = w * 0.15;

        return Column(
          children: [
            _box('User Input', Icons.edit_note, colors.primary,
                colors.onPrimary, boxW),
            _arrow(colors),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _box('Chat Provider', Icons.hub, colors.tertiaryContainer,
                    colors.onTertiaryContainer, boxW),
                SizedBox(width: arrowW),
                _box('AI Service', Icons.smart_toy, colors.secondaryContainer,
                    colors.onSecondaryContainer, boxW),
              ],
            ),
            _arrow(colors),
            _box('Gemini Nano (AICore)', Icons.memory, colors.primaryContainer,
                colors.onPrimaryContainer, boxW),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 16, color: colors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Isar DB (local storage)',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _box(String label, IconData icon, Color bg, Color fg, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Icon(Icons.arrow_downward,
              size: 20, color: colors.onSurfaceVariant.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context, ColorScheme colors) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Properties',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _legendItem(Icons.wifi_off, 'Fully offline — no internet required'),
          _legendItem(Icons.lock, 'Privacy-first — data never leaves device'),
          _legendItem(Icons.speed, 'Low latency — runs on-device NPU'),
          _legendItem(Icons.storage,
              'Persistent — conversations saved locally via Isar DB'),
          _legendItem(Icons.memory,
              'Model: Gemini Nano via Android AICore (max 256 tokens)'),
        ],
      ),
    );
  }

  Widget _legendItem(IconData icon, String text) {
    final theme = ThemeData();
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowSteps(BuildContext context, ColorScheme colors) {
    final theme = Theme.of(context);
    final steps = [
      ('1', 'You type a message in the chat input'),
      ('2', 'ChatProvider saves it to Isar DB and notifies listeners'),
      ('3', 'AIService builds a prompt with conversation history'),
      ('4', 'Gemini Nano (AICore) generates a response on-device'),
      ('5', 'Response streams back as markdown, saved to DB'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Message Flow',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...steps.map((step) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      step.$1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        step.$2,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

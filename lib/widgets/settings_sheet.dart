import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Generation Settings',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              _SliderRow(
                label: 'Temperature',
                value: settings.temperature,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                displayValue: settings.temperature.toStringAsFixed(1),
                onChanged: (v) => settings.updateTemperature(v),
              ),
              const SizedBox(height: 16),
              _SliderRow(
                label: 'Top-K',
                value: settings.topK.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                displayValue: '${settings.topK}',
                onChanged: (v) => settings.updateTopK(v.round()),
              ),
              const SizedBox(height: 16),
              _SliderRow(
                label: 'Max Tokens',
                value: settings.maxOutputTokens.toDouble(),
                min: 1,
                max: 256,
                divisions: 51,
                displayValue: '${settings.maxOutputTokens}',
                onChanged: (v) => settings.updateMaxOutputTokens(v.round()),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 100),
                child: Text(
                  'Output limit (AICore hard cap)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text('Auto-Continue',
                        style: theme.textTheme.bodyMedium),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: settings.autoContinue,
                          onChanged: (v) => settings.updateAutoContinue(v),
                        ),
                        Text(
                          'Extend long responses up to 5 rounds',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child:
                        Text('Token Stats', style: theme.textTheme.bodyMedium),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: settings.showTokenStats,
                          onChanged: (v) => settings.updateShowTokenStats(v),
                        ),
                        Text(
                          'Show tokens & speed on AI messages',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => settings.resetDefaults(),
                  child: const Text('Reset to Defaults'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: displayValue,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            displayValue,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

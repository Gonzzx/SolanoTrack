import 'package:flutter/material.dart';

import 'app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: AnimatedBuilder(
        animation: AppSettings.instance,
        builder: (context, _) {
          final settings = AppSettings.instance;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Appearance',
                children: [
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.smartphone),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selection) =>
                        settings.setThemeMode(selection.first),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Sensor Thresholds',
                subtitle:
                    'Calibrate the status labels shown on the dashboard.',
                children: [
                  _ThresholdSlider(
                    label: 'Soil "Dry" below',
                    value: settings.soilDry,
                    min: 0,
                    max: 100,
                    suffix: '%',
                    onChanged: (v) => settings.setThresholds(soilDry: v),
                  ),
                  _ThresholdSlider(
                    label: 'Soil "Wet" above',
                    value: settings.soilWet,
                    min: 0,
                    max: 100,
                    suffix: '%',
                    onChanged: (v) => settings.setThresholds(soilWet: v),
                  ),
                  _ThresholdSlider(
                    label: 'Humidity "Low" below',
                    value: settings.humidityLow,
                    min: 0,
                    max: 100,
                    suffix: '%',
                    onChanged: (v) => settings.setThresholds(humidityLow: v),
                  ),
                  _ThresholdSlider(
                    label: 'Comfortable temp — min',
                    value: settings.tempMin,
                    min: 0,
                    max: 40,
                    suffix: ' °C',
                    onChanged: (v) => settings.setThresholds(tempMin: v),
                  ),
                  _ThresholdSlider(
                    label: 'Comfortable temp — max',
                    value: settings.tempMax,
                    min: 0,
                    max: 45,
                    suffix: ' °C',
                    onChanged: (v) => settings.setThresholds(tempMax: v),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: settings.resetThresholds,
                      icon: const Icon(Icons.restore),
                      label: const Text('Reset to defaults'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SectionCard(
                title: 'About',
                children: [
                  Text(
                    'SolanoTrack',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'IoT-Enabled Magneto-UV Seed Monitoring and Treatment '
                    'System for eggplant germination. Version 1.0.0.',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '${value.toStringAsFixed(0)}$suffix',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

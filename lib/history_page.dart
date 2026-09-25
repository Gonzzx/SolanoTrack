import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'dashboard_page.dart' show Sparkline;

class HistoryEntry {
  HistoryEntry({
    required this.timestamp,
    required this.soilMoisture,
    required this.humidity,
    required this.tempC,
    required this.tempF,
  });

  final int timestamp;
  final double soilMoisture;
  final double humidity;
  final double tempC;
  final double tempF;

  factory HistoryEntry.fromMap(Map<dynamic, dynamic> map) {
    return HistoryEntry(
      timestamp:
          (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      soilMoisture: (map['soilMoisture'] as num?)?.toDouble() ?? 0,
      humidity: (map['humidity'] as num?)?.toDouble() ?? 0,
      tempC: (map['tempC'] as num?)?.toDouble() ?? 0,
      tempF: (map['tempF'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref(
    "History",
  );
  StreamSubscription<DatabaseEvent>? _sub;

  bool _loading = true;
  List<HistoryEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _sub = _historyRef.orderByKey().limitToLast(200).onValue.listen((event) {
      final value = event.snapshot.value;
      final entries = <HistoryEntry>[];
      if (value is Map) {
        value.forEach((key, val) {
          if (val is Map) {
            entries.add(HistoryEntry.fromMap(val));
          }
        });
      }
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() {
        _entries = entries;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _formatDateTime(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor History'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No history logged yet.\nReadings are recorded automatically '
                  'from the Dashboard every few minutes.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _TrendSummary(entries: _entries),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return Card(
                        elevation: 0,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _formatDateTime(entry.timestamp),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${entry.soilMoisture.toStringAsFixed(0)}%',
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${entry.humidity.toStringAsFixed(0)}%',
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${entry.tempC.toStringAsFixed(1)}°C',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _TrendSummary extends StatelessWidget {
  const _TrendSummary({required this.entries});

  final List<HistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Oldest-to-newest for a left-to-right trend line.
    final chronological = entries.reversed.toList();
    final soil = chronological.map((e) => e.soilMoisture).toList();
    final humidity = chronological.map((e) => e.humidity).toList();
    final temp = chronological.map((e) => e.tempC).toList();

    return Row(
      children: [
        Expanded(
          child: _TrendTile(label: 'Soil', color: Colors.brown, data: soil),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TrendTile(
            label: 'Humidity',
            color: Colors.blue,
            data: humidity,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TrendTile(label: 'Temp', color: Colors.red, data: temp),
        ),
      ],
    );
  }
}

class _TrendTile extends StatelessWidget {
  const _TrendTile({
    required this.label,
    required this.color,
    required this.data,
  });

  final String label;
  final Color color;
  final List<double> data;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            if (data.length >= 2)
              Sparkline(data: data, color: color)
            else
              const Text('—'),
          ],
        ),
      ),
    );
  }
}

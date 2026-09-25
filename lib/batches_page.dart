import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

const List<String> treatmentGroups = [
  'Control',
  'Magnet-only',
  'UV-C-only',
  'Combined',
];

class BatchRecord {
  BatchRecord({
    required this.id,
    required this.treatment,
    required this.timestamp,
    this.germinationRate,
    this.rootLength,
    this.shootHeight,
    this.notes,
  });

  final String id;
  final String treatment;
  final int timestamp;
  final double? germinationRate;
  final double? rootLength;
  final double? shootHeight;
  final String? notes;

  factory BatchRecord.fromMap(String id, Map<dynamic, dynamic> map) {
    return BatchRecord(
      id: id,
      treatment: map['treatment'] as String? ?? 'Control',
      timestamp:
          (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      germinationRate: (map['germinationRate'] as num?)?.toDouble(),
      rootLength: (map['rootLength'] as num?)?.toDouble(),
      shootHeight: (map['shootHeight'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
    );
  }
}

class BatchesPage extends StatefulWidget {
  const BatchesPage({super.key});

  @override
  State<BatchesPage> createState() => _BatchesPageState();
}

class _BatchesPageState extends State<BatchesPage> {
  final DatabaseReference _batchesRef = FirebaseDatabase.instance.ref(
    "Batches",
  );
  StreamSubscription<DatabaseEvent>? _sub;

  bool _loading = true;
  List<BatchRecord> _batches = [];

  @override
  void initState() {
    super.initState();
    _sub = _batchesRef.onValue.listen((event) {
      final value = event.snapshot.value;
      final batches = <BatchRecord>[];
      if (value is Map) {
        value.forEach((key, val) {
          if (val is Map) {
            batches.add(BatchRecord.fromMap(key.toString(), val));
          }
        });
      }
      batches.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() {
        _batches = batches;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _deleteBatch(String id) async {
    await _batchesRef.child(id).remove();
  }

  Future<void> _openAddBatchSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _AddBatchForm(
          onSubmit: (data) async {
            await _batchesRef.push().set({
              ...data,
              'timestamp': ServerValue.timestamp,
            });
          },
        ),
      ),
    );
  }

  String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Records'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddBatchSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Batch'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _batches.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No batches recorded yet.\nTap "New Batch" to log your first treatment batch.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _batches.length,
              itemBuilder: (context, index) {
                final batch = _batches[index];
                final isCurrent = index == 0;
                return Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                batch.treatment,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              const Text(
                                'Current',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteBatch(batch.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(batch.timestamp),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 20,
                          runSpacing: 6,
                          children: [
                            _Metric(
                              label: 'Germination',
                              value: batch.germinationRate != null
                                  ? '${batch.germinationRate!.toStringAsFixed(1)}%'
                                  : '—',
                            ),
                            _Metric(
                              label: 'Root length',
                              value: batch.rootLength != null
                                  ? '${batch.rootLength!.toStringAsFixed(1)} cm'
                                  : '—',
                            ),
                            _Metric(
                              label: 'Shoot height',
                              value: batch.shootHeight != null
                                  ? '${batch.shootHeight!.toStringAsFixed(1)} cm'
                                  : '—',
                            ),
                          ],
                        ),
                        if (batch.notes != null && batch.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(batch.notes!),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _AddBatchForm extends StatefulWidget {
  const _AddBatchForm({required this.onSubmit});

  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  @override
  State<_AddBatchForm> createState() => _AddBatchFormState();
}

class _AddBatchFormState extends State<_AddBatchForm> {
  final _formKey = GlobalKey<FormState>();
  String _treatment = treatmentGroups.first;
  final _germinationController = TextEditingController();
  final _rootController = TextEditingController();
  final _shootController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _germinationController.dispose();
    _rootController.dispose();
    _shootController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSubmit({
      'treatment': _treatment,
      if (_germinationController.text.isNotEmpty)
        'germinationRate': double.tryParse(_germinationController.text),
      if (_rootController.text.isNotEmpty)
        'rootLength': double.tryParse(_rootController.text),
      if (_shootController.text.isNotEmpty)
        'shootHeight': double.tryParse(_shootController.text),
      if (_notesController.text.isNotEmpty) 'notes': _notesController.text,
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Batch',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _treatment,
              decoration: const InputDecoration(labelText: 'Treatment group'),
              items: treatmentGroups
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _treatment = value ?? treatmentGroups.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _germinationController,
              decoration: const InputDecoration(
                labelText: 'Germination rate (%)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rootController,
              decoration: const InputDecoration(labelText: 'Root length (cm)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shootController,
              decoration: const InputDecoration(
                labelText: 'Shoot height (cm)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Batch'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

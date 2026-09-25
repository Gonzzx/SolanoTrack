import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import 'app_settings.dart';

const int _historyLimit = 20;
const Duration historyLogInterval = Duration(minutes: 5);

enum HealthLevel { good, warning, critical }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.title});
  final String title;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("Sensor");
  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref(
    "History",
  );
  final DatabaseReference _connectedRef = FirebaseDatabase.instance.ref(
    ".info/connected",
  );

  StreamSubscription<DatabaseEvent>? _dataSub;
  StreamSubscription<DatabaseEvent>? _connSub;

  int soilMoisture = 0;
  double humidity = 0.0;
  double tempC = 0.0;
  double tempF = 0.0;

  final List<double> _soilHistory = [];
  final List<double> _humidityHistory = [];
  final List<double> _tempHistory = [];

  bool _isLoading = true;
  bool _online = false;
  String? _errorMessage;
  DateTime? _lastUpdated;
  DateTime? _lastLoggedAt;

  @override
  void initState() {
    super.initState();
    _listenConnection();
    _listenData();
  }

  void _listenConnection() {
    _connSub?.cancel();
    _connSub = _connectedRef.onValue.listen((event) {
      setState(() {
        _online = event.snapshot.value as bool? ?? false;
      });
    });
  }

  void _listenData() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _dataSub?.cancel();
    _dataSub = _dbRef.onValue.listen(
      (event) {
        final value = event.snapshot.value;
        if (value is Map) {
          setState(() {
            soilMoisture = (value["SoilMoisture"] as num?)?.toInt() ?? 0;
            humidity = (value["Humidity"] as num?)?.toDouble() ?? 0.0;
            tempC = (value["TemperatureC"] as num?)?.toDouble() ?? 0.0;
            tempF = (value["TemperatureF"] as num?)?.toDouble() ?? 0.0;
            _isLoading = false;
            _lastUpdated = DateTime.now();
            _pushHistory(_soilHistory, soilMoisture.toDouble());
            _pushHistory(_humidityHistory, humidity);
            _pushHistory(_tempHistory, tempC);
          });
          _maybeLogHistory();
        }
      },
      onError: (Object error) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to reach sensor: $error';
        });
      },
    );
  }

  void _pushHistory(List<double> history, double value) {
    history.add(value);
    if (history.length > _historyLimit) {
      history.removeAt(0);
    }
  }

  void _maybeLogHistory() {
    final now = DateTime.now();
    if (_lastLoggedAt != null &&
        now.difference(_lastLoggedAt!) < historyLogInterval) {
      return;
    }
    _lastLoggedAt = now;
    _historyRef.push().set({
      'soilMoisture': soilMoisture,
      'humidity': humidity,
      'tempC': tempC,
      'tempF': tempF,
      'timestamp': ServerValue.timestamp,
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  List<String> _issues(AppSettings settings) {
    final issues = <String>[];
    if (soilMoisture < settings.soilDry - 10) {
      issues.add('Soil is very dry — water the plant soon.');
    } else if (soilMoisture > settings.soilWet + 15) {
      issues.add('Soil is saturated — check for overwatering.');
    }
    if (humidity < settings.humidityLow - 10) {
      issues.add('Humidity is very low.');
    }
    if (tempC < settings.tempMin - 8 || tempC > settings.tempMax + 7) {
      issues.add('Temperature is outside a safe range.');
    }
    return issues;
  }

  HealthLevel _overallHealth(AppSettings settings) {
    final critical =
        soilMoisture < settings.soilDry - 10 ||
        tempC < settings.tempMin - 8 ||
        tempC > settings.tempMax + 7 ||
        soilMoisture > settings.soilWet + 15;
    final warning =
        soilMoisture < settings.soilDry ||
        humidity < settings.humidityLow - 10 ||
        tempC < settings.tempMin ||
        tempC > settings.tempMax ||
        soilMoisture > settings.soilWet;
    if (critical) return HealthLevel.critical;
    if (warning) return HealthLevel.warning;
    return HealthLevel.good;
  }

  String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title),
            const SizedBox(width: 10),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _online ? Colors.lightGreenAccent : Colors.redAccent,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _listenData,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: AppSettings.instance,
        builder: (context, _) => _buildBody(context, AppSettings.instance),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppSettings settings) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _listenData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final health = _overallHealth(settings);
    final issues = _issues(settings);

    return RefreshIndicator(
      onRefresh: () async => _listenData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HealthBanner(level: health, issues: issues),
          const SizedBox(height: 16),
          if (_lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Last updated ${_formatTime(_lastUpdated!)} · ${_online ? "Online" : "Offline"}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          SensorCard(
            title: "Soil Moisture",
            icon: Icons.water_drop,
            color: Colors.brown,
            status: settings.soilStatus(soilMoisture),
            numericValue: soilMoisture.toDouble(),
            valueSuffix: '%',
            percent: soilMoisture / 100,
            history: List.of(_soilHistory),
          ),
          SensorCard(
            title: "Humidity",
            icon: Icons.cloud,
            color: Colors.blue,
            status: settings.humidityStatus(humidity),
            numericValue: humidity,
            valueSuffix: '%',
            decimals: 1,
            percent: humidity / 100,
            history: List.of(_humidityHistory),
          ),
          SensorCard(
            title: "Temperature",
            icon: Icons.thermostat,
            color: Colors.red,
            status: settings.tempStatus(tempC),
            numericValue: tempC,
            valueSuffix: ' °C',
            decimals: 1,
            secondaryText: '${tempF.toStringAsFixed(1)} °F',
            history: List.of(_tempHistory),
          ),
          const SizedBox(height: 8),
          const ControlPanel(),
        ],
      ),
    );
  }
}

class HealthBanner extends StatelessWidget {
  const HealthBanner({super.key, required this.level, required this.issues});

  final HealthLevel level;
  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String title) = switch (level) {
      HealthLevel.good => (Colors.green, Icons.eco, 'Plant is healthy'),
      HealthLevel.warning => (
        Colors.orange,
        Icons.warning_amber_rounded,
        'Needs attention',
      ),
      HealthLevel.critical => (
        Colors.red,
        Icons.error_outline,
        'Critical condition',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• $issue',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SensorCard extends StatelessWidget {
  const SensorCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.status,
    required this.numericValue,
    required this.valueSuffix,
    required this.history,
    this.percent,
    this.decimals = 0,
    this.secondaryText,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String status;
  final double numericValue;
  final String valueSuffix;
  final List<double> history;
  final double? percent;
  final int decimals;
  final String? secondaryText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            _buildIconArea(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: numericValue, end: numericValue),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, _) => Text(
                          '${value.toStringAsFixed(decimals)}$valueSuffix',
                          style: textTheme.headlineSmall,
                        ),
                      ),
                      if (secondaryText != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '/ $secondaryText',
                          style: textTheme.bodyMedium?.copyWith(
                            color: textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      status,
                      style: textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (history.length >= 2) ...[
              const SizedBox(width: 12),
              Sparkline(data: history, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconArea() {
    if (percent != null) {
      final clamped = percent!.clamp(0.0, 1.0);
      return SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: clamped, end: clamped),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 5,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Icon(icon, color: color, size: 22),
          ],
        ),
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  final DatabaseReference _controlRef = FirebaseDatabase.instance.ref(
    "Control",
  );
  StreamSubscription<DatabaseEvent>? _sub;

  bool _loading = true;
  bool _uvOn = false;
  int _uvDuration = 1;
  int _uvLamp = 0;

  @override
  void initState() {
    super.initState();
    _sub = _controlRef.onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        setState(() {
          _uvOn = value["UV"] as bool? ?? false;
          _uvDuration = (value["UVDuration"] as num?)?.toInt() ?? 1;
          _uvLamp = (value["UVLamp"] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _setUvOn(bool value) async {
    setState(() => _uvOn = value);
    await _controlRef.update({"UV": value});
  }

  Future<void> _setUvDuration(int value) async {
    if (value < 1) return;
    setState(() => _uvDuration = value);
    await _controlRef.update({"UVDuration": value});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Device Controls',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        _ControlCard(
          title: 'UV Lamp',
          icon: Icons.wb_sunny,
          color: Colors.amber.shade700,
          isOn: _uvOn,
          onToggle: _setUvOn,
          duration: _uvDuration,
          onDurationChanged: _setUvDuration,
          subtitle: 'Reported level: $_uvLamp',
        ),
      ],
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.isOn,
    required this.onToggle,
    required this.duration,
    required this.onDurationChanged,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final Color color;
  final bool isOn;
  final ValueChanged<bool> onToggle;
  final int duration;
  final ValueChanged<int> onDurationChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: subtitle != null ? Text(subtitle!) : null,
              value: isOn,
              onChanged: onToggle,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Text('Duration (min)'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: duration > 1
                        ? () => onDurationChanged(duration - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$duration',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => onDurationChanged(duration + 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.data, required this.color});

  final List<double> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 36,
      child: CustomPaint(painter: _SparklinePainter(data: data, color: color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.data, required this.color});

  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minV = data.reduce(math.min);
    final maxV = data.reduce(math.max);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : maxV - minV;

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final normalized = (data[i] - minV) / range;
      final y = size.height - normalized * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}

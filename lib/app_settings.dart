import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const double defaultSoilDry = 30;
  static const double defaultSoilWet = 70;
  static const double defaultHumidityLow = 30;
  static const double defaultTempMin = 18;
  static const double defaultTempMax = 28;

  ThemeMode themeMode = ThemeMode.system;
  double soilDry = defaultSoilDry;
  double soilWet = defaultSoilWet;
  double humidityLow = defaultHumidityLow;
  double tempMin = defaultTempMin;
  double tempMax = defaultTempMax;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString('themeMode');
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => ThemeMode.system,
    );
    soilDry = prefs.getDouble('soilDry') ?? defaultSoilDry;
    soilWet = prefs.getDouble('soilWet') ?? defaultSoilWet;
    humidityLow = prefs.getDouble('humidityLow') ?? defaultHumidityLow;
    tempMin = prefs.getDouble('tempMin') ?? defaultTempMin;
    tempMax = prefs.getDouble('tempMax') ?? defaultTempMax;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  Future<void> setThresholds({
    double? soilDry,
    double? soilWet,
    double? humidityLow,
    double? tempMin,
    double? tempMax,
  }) async {
    this.soilDry = soilDry ?? this.soilDry;
    this.soilWet = soilWet ?? this.soilWet;
    this.humidityLow = humidityLow ?? this.humidityLow;
    this.tempMin = tempMin ?? this.tempMin;
    this.tempMax = tempMax ?? this.tempMax;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('soilDry', this.soilDry);
    await prefs.setDouble('soilWet', this.soilWet);
    await prefs.setDouble('humidityLow', this.humidityLow);
    await prefs.setDouble('tempMin', this.tempMin);
    await prefs.setDouble('tempMax', this.tempMax);
  }

  Future<void> resetThresholds() => setThresholds(
    soilDry: defaultSoilDry,
    soilWet: defaultSoilWet,
    humidityLow: defaultHumidityLow,
    tempMin: defaultTempMin,
    tempMax: defaultTempMax,
  );

  String soilStatus(int value) {
    if (value < soilDry - 10) return 'Very dry';
    if (value < soilDry) return 'Dry';
    if (value < soilWet) return 'Moist';
    if (value <= soilWet + 15) return 'Wet';
    return 'Saturated';
  }

  String humidityStatus(double value) {
    if (value < humidityLow - 10) return 'Very low';
    if (value < humidityLow) return 'Low';
    if (value < 60) return 'Normal';
    return 'High';
  }

  String tempStatus(double celsius) {
    if (celsius < tempMin - 8) return 'Too cold';
    if (celsius < tempMin) return 'Cold';
    if (celsius < tempMax) return 'Comfortable';
    if (celsius <= tempMax + 7) return 'Hot';
    return 'Too hot';
  }
}

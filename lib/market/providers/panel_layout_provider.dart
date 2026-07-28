import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/panel_rect.dart';

class PanelLayoutProvider extends ChangeNotifier {
  static const _prefsKey = 'home_panel_layout_v1';
  static const double minSize = 0.15;

  static const Map<String, PanelRect> defaultLayout = {
    'sector_movers': PanelRect(x: 0.0, y: 0.0, w: 0.28, h: 1.0),
    'live_trading': PanelRect(x: 0.28, y: 0.0, w: 0.72, h: 0.5),
    'breakout': PanelRect(x: 0.28, y: 0.5, w: 0.72, h: 0.5),
  };

  Map<String, PanelRect> layout = Map.from(defaultLayout);
  bool editMode = false;
  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        layout = decoded.map(
          (k, v) => MapEntry(k, PanelRect.fromJson(v as Map<String, dynamic>)),
        );
      } catch (_) {
        layout = Map.from(defaultLayout);
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(layout.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_prefsKey, encoded);
  }

  Future<void> resetLayout() async {
    layout = Map.from(defaultLayout);
    notifyListeners();
    await save();
  }

  void toggleEditMode() {
    editMode = !editMode;
    notifyListeners();
  }

  void updateRect(String id, PanelRect rect) {
    layout[id] = rect;
    notifyListeners();
  }
}
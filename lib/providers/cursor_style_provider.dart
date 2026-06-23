import 'package:flutter/material.dart';
import '../platform/service_locator.dart';

// ─────────────────────────────────────────────────────────────────
//  光标风格枚举
// ─────────────────────────────────────────────────────────────────

enum CursorStyle {
  /// 墨滴：呼吸发光竖线 + 墨水粒子拖尾 + 点击涟漪（纯纯手写风）
  inkDrop,

  /// 霓虹：渐变色竖线 + 强烈外发光，无粒子，适合深色模式
  neon,

  /// 极简：纯细线，无发光、无粒子、无涟漪，专注写作
  minimal,
}

extension CursorStyleExt on CursorStyle {
  String get label {
    switch (this) {
      case CursorStyle.inkDrop:
        return '墨滴';
      case CursorStyle.neon:
        return '霓虹';
      case CursorStyle.minimal:
        return '极简';
    }
  }

  String get emoji {
    switch (this) {
      case CursorStyle.inkDrop:
        return '🖋️';
      case CursorStyle.neon:
        return '✨';
      case CursorStyle.minimal:
        return '｜';
    }
  }

  String get description {
    switch (this) {
      case CursorStyle.inkDrop:
        return '墨水粒子拖尾，仿手写质感';
      case CursorStyle.neon:
        return '渐变发光，沉浸深色氛围';
      case CursorStyle.minimal:
        return '纯粹细线，专注无干扰';
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────────

class CursorStyleProvider extends ChangeNotifier {
  static const _key = 'cursor_style';

  CursorStyle _style = CursorStyle.inkDrop;
  CursorStyle get style => _style;

  CursorStyleProvider() {
    _load();
  }

  Future<void> _load() async {
    final idx = await ServiceLocator.kvStore.getInt(_key) ?? 0;
    _style = CursorStyle.values[idx.clamp(0, CursorStyle.values.length - 1)];
    notifyListeners();
  }

  Future<void> setStyle(CursorStyle style) async {
    if (_style == style) return;
    _style = style;
    notifyListeners();
    await ServiceLocator.kvStore.setInt(_key, style.index);
  }
}

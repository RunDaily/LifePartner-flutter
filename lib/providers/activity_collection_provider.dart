import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/activity_collection.dart';
import '../platform/service_locator.dart';

// ─────────────────────────────────────────────────────────────────
//  ActivityCollectionProvider
//
//  管理用户自己的「活动集」——即用户选择或创建的活动定义列表。
//  持久化：KV Store（JSON List），无需额外数据库表。
//
//  每条活动的打卡记录存在 RecordProvider（type=event, extra={activityId:...}）。
// ─────────────────────────────────────────────────────────────────

class ActivityCollectionProvider extends ChangeNotifier {
  static const _kvKey = 'activity_collection_v1';

  List<ActivityDefinition> _activities = [];
  bool _isLoaded = false;

  List<ActivityDefinition> get activities => _activities;
  bool get isLoaded => _isLoaded;
  bool get isEmpty => _activities.isEmpty;

  ActivityCollectionProvider() {
    _load();
  }

  // ── 加载 / 保存 ───────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final json = await ServiceLocator.kvStore.getString(_kvKey);
      if (json != null && json.isNotEmpty) {
        final list = jsonDecode(json) as List<dynamic>;
        _activities = list
            .map((e) =>
                ActivityDefinition.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[ActivityCollectionProvider] 加载失败: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final json = jsonEncode(_activities.map((a) => a.toMap()).toList());
      await ServiceLocator.kvStore.setString(_kvKey, json);
    } catch (e) {
      debugPrint('[ActivityCollectionProvider] 保存失败: $e');
    }
  }

  // ── 操作 ──────────────────────────────────────────────────────

  /// 从预置库添加活动（引导选择时调用）
  Future<void> addPreset(ActivityDefinition preset) async {
    // 避免重复添加
    if (_activities.any((a) => a.id == preset.id)) return;
    _activities = [..._activities, preset];
    notifyListeners();
    await _save();
  }

  /// 批量添加预置（引导完成时调用）
  Future<void> addPresets(List<ActivityDefinition> presets) async {
    final existingIds = _activities.map((a) => a.id).toSet();
    final newOnes = presets.where((p) => !existingIds.contains(p.id)).toList();
    if (newOnes.isEmpty) return;
    _activities = [..._activities, ...newOnes];
    notifyListeners();
    await _save();
  }

  /// 用户手动创建自定义活动
  Future<ActivityDefinition> createCustom({
    required String name,
    required String emoji,
    required ActivityCategory category,
    List<String>? gradientHex,
    String description = '',
  }) async {
    final now = DateTime.now();
    final activity = ActivityDefinition(
      id: 'custom_${const Uuid().v4()}',
      name: name,
      emoji: emoji,
      category: category,
      gradientHex: gradientHex ?? _defaultGradientForCategory(category),
      description: description,
      isPreset: false,
      createdAt: now,
    );
    _activities = [..._activities, activity];
    notifyListeners();
    await _save();
    return activity;
  }

  /// 删除活动（仅从活动集移除，历史打卡记录不受影响）
  Future<void> remove(String activityId) async {
    _activities = _activities.where((a) => a.id != activityId).toList();
    notifyListeners();
    await _save();
  }

  /// 写入 AI 生成的专属文案（首次打卡后后台异步调用）
  ///
  /// 只在以下情况执行：
  /// 1. 活动还在集合中
  /// 2. 该活动尚无 mottoLine（避免重复消耗 token）
  Future<void> updateMotto(String activityId, String motto) async {
    final idx = _activities.indexWhere((a) => a.id == activityId);
    if (idx == -1) return;
    if (_activities[idx].mottoLine != null &&
        _activities[idx].mottoLine!.isNotEmpty) return;
    final updated = _activities[idx].withMotto(motto);
    _activities = [..._activities]..[idx] = updated;
    notifyListeners();
    await _save();
  }

  /// 是否已在活动集中
  bool contains(String activityId) =>
      _activities.any((a) => a.id == activityId);

  /// 按分类获取
  List<ActivityDefinition> byCategory(ActivityCategory category) =>
      _activities.where((a) => a.category == category).toList();

  // ── 工具 ─────────────────────────────────────────────────────

  static List<String> _defaultGradientForCategory(ActivityCategory cat) {
    return cat.defaultGradient;
  }
}

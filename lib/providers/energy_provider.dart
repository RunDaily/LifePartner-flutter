import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/energy_beans.dart';
import '../platform/service_locator.dart';

// ─────────────────────────────────────────────────────────────────
//  AI 能量豆 Provider
//
//  职责：
//  · 维护用户能量豆余量状态
//  · 提供消耗/补充接口
//  · 检测每日自动补充（打开 App 时触发）
//  · 持久化到 KV 存储
// ─────────────────────────────────────────────────────────────────

class EnergyProvider extends ChangeNotifier {
  static const _storageKey = 'energy_beans_v1';

  EnergyBeansState _state = const EnergyBeansState();
  bool _isLoaded = false;

  // ── 最近一次变动信息（供 UI 动画反馈）───────────────────────
  EnergyBeansEvent? _lastEvent;
  int? _lastDelta;

  // ── Getters ─────────────────────────────────────────────────

  EnergyBeansState get state => _state;

  /// 当前能量豆余量
  int get current => _state.current;

  /// 是否有足够能量豆触发 AI 评论
  bool get canTriggerAiComment => _state.current >= kCommentCostBeans;

  bool get isLoaded => _isLoaded;

  /// 最近一次变动事件（用于 UI 动画）
  EnergyBeansEvent? get lastEvent => _lastEvent;
  int? get lastDelta => _lastDelta;

  EnergyProvider() {
    _load();
  }

  // ─────────────────────────────────────────────────────────────
  //  加载 / 保存
  // ─────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final json = await ServiceLocator.kvStore.getString(_storageKey);
      if (json != null && json.isNotEmpty) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _state = EnergyBeansState.fromMap(map);
        // 加载后检测每日补充
        _checkDailyRestore();
      } else {
        // 首次启动：赠送新手礼包
        _state = const EnergyBeansState(
          current: kInitialBeans,
          totalEarned: kInitialBeans,
        );
        await _save();
      }
    } catch (e) {
      debugPrint('[EnergyProvider] 加载失败: $e');
      _state = const EnergyBeansState();
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final json = jsonEncode(_state.toMap());
      await ServiceLocator.kvStore.setString(_storageKey, json);
    } catch (e) {
      debugPrint('[EnergyProvider] 保存失败: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  每日补充逻辑
  // ─────────────────────────────────────────────────────────────

  /// 检测是否可以领取今日每日补充
  bool get canClaimDailyReward {
    final today = _todayKey();
    return _state.dailyRewardDate != today;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 每日自动检测补充（加载时调用）
  void _checkDailyRestore() {
    if (!canClaimDailyReward) return;
    final today = _todayKey();
    final newAmount = (_state.current + kDailyRewardBeans).clamp(0, kMaxBeans);
    _state = _state.copyWith(
      current: newAmount,
      dailyRewardClaimed: true,
      dailyRewardDate: today,
      totalEarned: _state.totalEarned + kDailyRewardBeans,
    );
    _lastEvent = EnergyBeansEvent.dailyRestore;
    _lastDelta = kDailyRewardBeans;
    // 注意：此处不 notifyListeners()，在 _load() 的 finally 中统一通知
  }

  /// 手动领取今日能量豆补充（用户主动点击领取按钮）
  ///
  /// 返回 true = 成功领取，false = 今天已领取过
  Future<bool> claimDailyReward() async {
    if (!canClaimDailyReward) return false;

    final today = _todayKey();
    final newAmount = (_state.current + kDailyRewardBeans).clamp(0, kMaxBeans);
    _state = _state.copyWith(
      current: newAmount,
      dailyRewardClaimed: true,
      dailyRewardDate: today,
      totalEarned: _state.totalEarned + kDailyRewardBeans,
    );
    _lastEvent = EnergyBeansEvent.dailyRestore;
    _lastDelta = kDailyRewardBeans;
    notifyListeners();
    await _save();
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  //  消耗接口
  // ─────────────────────────────────────────────────────────────

  /// 消耗能量豆触发 AI 评论
  ///
  /// 返回 true = 消耗成功；false = 余量不足
  Future<bool> consumeForAiComment() async {
    if (_state.current < kCommentCostBeans) return false;

    _state = _state.copyWith(
      current: _state.current - kCommentCostBeans,
      totalConsumed: _state.totalConsumed + kCommentCostBeans,
      lastConsumedAt: DateTime.now().toIso8601String(),
    );
    _lastEvent = EnergyBeansEvent.aiComment;
    _lastDelta = -kCommentCostBeans;
    notifyListeners();
    await _save();
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  //  奖励接口
  // ─────────────────────────────────────────────────────────────

  /// 添加能量豆（写作奖励、活动等）
  ///
  /// [event] 来源事件（用于 UI 展示）
  Future<void> addBeans(EnergyBeansEvent event) async {
    if (event.delta <= 0) return; // 仅处理正向奖励
    final newAmount = (_state.current + event.delta).clamp(0, kMaxBeans);
    _state = _state.copyWith(
      current: newAmount,
      totalEarned: _state.totalEarned + event.delta,
    );
    _lastEvent = event;
    _lastDelta = event.delta;
    notifyListeners();
    await _save();
  }

  // ─────────────────────────────────────────────────────────────
  //  调试工具（仅 Debug 模式）
  // ─────────────────────────────────────────────────────────────

  /// 重置能量豆状态（仅用于调试）
  Future<void> debugReset() async {
    if (!kDebugMode) return;
    _state = const EnergyBeansState(
      current: kInitialBeans,
      totalEarned: kInitialBeans,
    );
    _lastEvent = null;
    _lastDelta = null;
    notifyListeners();
    await _save();
    debugPrint('[EnergyProvider] 已重置能量豆');
  }

  /// 直接设置能量豆数量（仅用于调试）
  Future<void> debugSetBeans(int amount) async {
    if (!kDebugMode) return;
    _state = _state.copyWith(current: amount.clamp(0, kMaxBeans));
    notifyListeners();
    await _save();
  }
}

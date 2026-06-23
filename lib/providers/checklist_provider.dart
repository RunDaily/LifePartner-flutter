import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/checklist.dart';
import '../models/checklist_template.dart';
import '../platform/service_locator.dart';
import '../services/ai_service.dart';

// ─────────────────────────────────────────────────────────────────
//  ChecklistProvider —— 清单状态管理
//
//  【缓存机制说明 v4】
//
//  问题背景：
//    Provider 中大量计算属性（tagCounts、temporalGroupedByDate、
//    pinnedStructuralChecklists 等）每次被 Widget tree rebuild 触发时
//    都会重新遍历 _checklists，在列表较大时造成不必要的 CPU 开销。
//
//  解决方案：惰性失效缓存（Lazy-Invalidation Cache）
//
//  ┌──────────────────────────────────────────────────────────────┐
//  │  核心规则                                                    │
//  │                                                              │
//  │  1. 每个可缓存的计算属性配有对应的私有缓存字段（? 可空）        │
//  │  2. 数据发生任何变更时调用 _invalidateCache()，统一置为 null   │
//  │  3. getter 被访问时：                                        │
//  │       - 若缓存有效（非 null），直接返回缓存                    │
//  │       - 若缓存无效（null），重新计算并写入缓存再返回            │
//  │  4. 时间敏感的 getter（today / overdue / upcoming）额外存储   │
//  │     缓存日期，若当前日期与缓存日期不符则视为无效（跨天失效）    │
//  │                                                              │
//  │  被缓存的属性（按优先级排列）：                               │
//  │    高开销（O(n·m)）：tagCounts、sceneCounts                   │
//  │    高复杂度（建立 Map/多次排序）：temporalGroupedByDate        │
//  │    多次调用基础视图：activeChecklists、structuralChecklists、  │
//  │                      temporalChecklists                      │
//  │    时间依赖：todayChecklists、overdueChecklists、             │
//  │              upcomingTemporalChecklists、                    │
//  │              scheduledTemporalChecklists、todayPendingItemCount│
//  │    结构型派生：pinnedStructuralChecklists、                   │
//  │               unpinnedStructuralChecklists、                 │
//  │               dueSoonStructuralChecklists                    │
//  └──────────────────────────────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────

class ChecklistProvider extends ChangeNotifier {
  List<Checklist> _checklists = [];
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Checklist> get checklists => _checklists;
  bool get isEmpty => _checklists.isEmpty;

  // ── 缓存字段 ──────────────────────────────────────────────────────
  //
  // 命名规则：_cached<PropertyName>
  // 时间依赖缓存额外携带 _cached<Name>Date 字段（跨天失效）

  List<Checklist>? _cachedActiveChecklists;
  List<Checklist>? _cachedArchivedChecklists;
  List<Checklist>? _cachedStructuralChecklists;
  List<Checklist>? _cachedTemporalChecklists;
  List<Checklist>? _cachedPinnedStructuralChecklists;
  List<Checklist>? _cachedUnpinnedStructuralChecklists;
  List<Checklist>? _cachedDueSoonStructuralChecklists;
  List<Checklist>? _cachedScheduledTemporalChecklists;
  List<Checklist>? _cachedUndatedTemporalChecklists;
  List<Checklist>? _cachedInboxTemporalChecklists;
  Map<DateTime, List<Checklist>>? _cachedTemporalGroupedByDate;
  Map<ChecklistScene, int>? _cachedSceneCounts;
  Map<String, int>? _cachedTagCounts;

  // 时间敏感缓存的基准日期（用于跨天失效检测）
  DateTime? _cachedTodayDate;
  List<Checklist>? _cachedTodayChecklists;
  int? _cachedTodayPendingItemCount;
  List<Checklist>? _cachedOverdueChecklists;
  List<Checklist>? _cachedUpcomingTemporalChecklists;

  /// 统一失效所有缓存。
  ///
  /// 在任何改变 _checklists 的操作完成后、调用 notifyListeners() 之前执行。
  void _invalidateCache() {
    _cachedActiveChecklists = null;
    _cachedArchivedChecklists = null;
    _cachedStructuralChecklists = null;
    _cachedTemporalChecklists = null;
    _cachedPinnedStructuralChecklists = null;
    _cachedUnpinnedStructuralChecklists = null;
    _cachedDueSoonStructuralChecklists = null;
    _cachedScheduledTemporalChecklists = null;
    _cachedUndatedTemporalChecklists = null;
    _cachedInboxTemporalChecklists = null;
    _cachedTemporalGroupedByDate = null;
    _cachedSceneCounts = null;
    _cachedTagCounts = null;
    _cachedTodayDate = null;
    _cachedTodayChecklists = null;
    _cachedTodayPendingItemCount = null;
    _cachedOverdueChecklists = null;
    _cachedUpcomingTemporalChecklists = null;
  }

  /// 检查时间依赖缓存的日期是否仍有效（同一天则有效）。
  bool _isTodayCacheValid() {
    if (_cachedTodayDate == null) return false;
    final now = DateTime.now();
    return _cachedTodayDate!.year == now.year &&
        _cachedTodayDate!.month == now.month &&
        _cachedTodayDate!.day == now.day;
  }

  // ── 基础过滤视图 ──────────────────────────────────────────────────

  List<Checklist> get activeChecklists =>
      _cachedActiveChecklists ??= _checklists
          .where((c) => c.status == ChecklistStatus.active)
          .toList();

  List<Checklist> get archivedChecklists =>
      _cachedArchivedChecklists ??= _checklists
          .where((c) => c.status == ChecklistStatus.archived)
          .toList();

  List<Checklist> byScene(ChecklistScene scene) =>
      _checklists.where((c) => c.scene == scene).toList();

  // ── 时态型视图 ────────────────────────────────────────────────────

  /// 所有活跃的时态型清单
  List<Checklist> get temporalChecklists =>
      _cachedTemporalChecklists ??= _checklists
          .where((c) =>
              c.checklistType == ChecklistType.temporal &&
              c.status == ChecklistStatus.active)
          .toList();

  /// 今日时态清单（scheduledDate = 今天）
  ///
  /// 跨天失效：若缓存日期不是今天，自动重新计算。
  List<Checklist> get todayChecklists {
    if (_isTodayCacheValid() && _cachedTodayChecklists != null) {
      return _cachedTodayChecklists!;
    }
    final now = DateTime.now();
    _cachedTodayDate = DateTime(now.year, now.month, now.day);
    _cachedTodayChecklists = _checklists.where((c) {
      if (c.checklistType != ChecklistType.temporal) return false;
      if (c.status == ChecklistStatus.archived) return false;
      if (c.scheduledDate == null) return false;
      final s = c.scheduledDate!;
      return s.year == now.year && s.month == now.month && s.day == now.day;
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    // 同时失效依赖 today 的派生缓存
    _cachedTodayPendingItemCount = null;
    return _cachedTodayChecklists!;
  }

  /// 无日期的时态清单（用户没有绑定特定日期，类似「随时待办」）
  List<Checklist> get undatedTemporalChecklists =>
      _cachedUndatedTemporalChecklists ??= _checklists
          .where((c) =>
              c.checklistType == ChecklistType.temporal &&
              c.status == ChecklistStatus.active &&
              c.scheduledDate == null)
          .toList();

  /// 逾期未完成的时态清单（scheduledDate 在今天之前）
  ///
  /// 跨天失效：overdue 结果依赖当天日期，与 today 缓存共用同一日期基准。
  List<Checklist> get overdueChecklists {
    if (_isTodayCacheValid() && _cachedOverdueChecklists != null) {
      return _cachedOverdueChecklists!;
    }
    // 确保今日日期基准已初始化（todayChecklists 先于 overdue 调用时已写入）
    if (_cachedTodayDate == null) {
      final now = DateTime.now();
      _cachedTodayDate = DateTime(now.year, now.month, now.day);
    }
    _cachedOverdueChecklists = _checklists
        .where((c) => c.isOverdue)
        .toList()
      ..sort((a, b) => a.scheduledDate!.compareTo(b.scheduledDate!));
    return _cachedOverdueChecklists!;
  }

  /// 即将到期的时态清单（未来 7 天内有 scheduledDate）
  ///
  /// 跨天失效：与 today 缓存共用同一日期基准。
  List<Checklist> get upcomingTemporalChecklists {
    if (_isTodayCacheValid() && _cachedUpcomingTemporalChecklists != null) {
      return _cachedUpcomingTemporalChecklists!;
    }
    final now = DateTime.now();
    _cachedTodayDate ??= DateTime(now.year, now.month, now.day);
    final today = _cachedTodayDate!;
    final in7Days = today.add(const Duration(days: 7));
    _cachedUpcomingTemporalChecklists = _checklists.where((c) {
      if (c.checklistType != ChecklistType.temporal) return false;
      if (c.status == ChecklistStatus.archived) return false;
      if (c.scheduledDate == null) return false;
      if (c.isToday) return false; // 今天的单独展示
      final s = DateTime(
          c.scheduledDate!.year, c.scheduledDate!.month, c.scheduledDate!.day);
      return s.isAfter(today) && s.isBefore(in7Days);
    }).toList()
      ..sort((a, b) => a.scheduledDate!.compareTo(b.scheduledDate!));
    return _cachedUpcomingTemporalChecklists!;
  }

  // ── 日程视图：按日期分组 ───────────────────────────────────────────

  /// 所有有日期的时态清单（用于日程页），按日期正序排列
  List<Checklist> get scheduledTemporalChecklists =>
      _cachedScheduledTemporalChecklists ??= _checklists.where((c) {
        if (c.checklistType != ChecklistType.temporal) return false;
        if (c.status == ChecklistStatus.archived) return false;
        return c.scheduledDate != null;
      }).toList()
        ..sort((a, b) => a.scheduledDate!.compareTo(b.scheduledDate!));

  /// 按日期分组（Map key = 当天零点 DateTime）
  /// 返回有序的 Map（从最近日期开始）
  ///
  /// 依赖 scheduledTemporalChecklists，自动受益于其缓存。
  Map<DateTime, List<Checklist>> get temporalGroupedByDate {
    if (_cachedTemporalGroupedByDate != null) {
      return _cachedTemporalGroupedByDate!;
    }
    final result = <DateTime, List<Checklist>>{};
    for (final c in scheduledTemporalChecklists) {
      final d = c.scheduledDate!;
      final key = DateTime(d.year, d.month, d.day);
      result.putIfAbsent(key, () => []).add(c);
    }
    _cachedTemporalGroupedByDate = result;
    return _cachedTemporalGroupedByDate!;
  }

  /// 指定日期的时态清单（不缓存：入参不同，缓存收益低）
  List<Checklist> temporalForDay(DateTime date) {
    return _checklists.where((c) {
      if (c.checklistType != ChecklistType.temporal) return false;
      if (c.status == ChecklistStatus.archived) return false;
      if (c.scheduledDate == null) return false;
      final d = c.scheduledDate!;
      return d.year == date.year &&
          d.month == date.month &&
          d.day == date.day;
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 指定周内的时态清单（不缓存：入参不同，缓存收益低）
  List<Checklist> temporalForWeek(DateTime weekStart) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return _checklists.where((c) {
      if (c.checklistType != ChecklistType.temporal) return false;
      if (c.status == ChecklistStatus.archived) return false;
      if (c.scheduledDate == null) return false;
      final d = DateTime(
          c.scheduledDate!.year, c.scheduledDate!.month, c.scheduledDate!.day);
      return !d.isBefore(start) && d.isBefore(end);
    }).toList()
      ..sort((a, b) => a.scheduledDate!.compareTo(b.scheduledDate!));
  }

  /// 无日期的时态清单（收件箱式，随时待办）
  List<Checklist> get inboxTemporalChecklists =>
      _cachedInboxTemporalChecklists ??= _checklists
          .where((c) =>
              c.checklistType == ChecklistType.temporal &&
              c.status == ChecklistStatus.active &&
              c.scheduledDate == null)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ── 结构型视图 ────────────────────────────────────────────────────

  /// 所有活跃的结构型清单
  List<Checklist> get structuralChecklists =>
      _cachedStructuralChecklists ??= _checklists
          .where((c) =>
              c.checklistType == ChecklistType.structural &&
              c.status == ChecklistStatus.active)
          .toList();

  /// 置顶的结构型清单
  List<Checklist> get pinnedStructuralChecklists =>
      _cachedPinnedStructuralChecklists ??= structuralChecklists
          .where((c) => c.isPinned)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// 未置顶的结构型清单
  List<Checklist> get unpinnedStructuralChecklists =>
      _cachedUnpinnedStructuralChecklists ??= structuralChecklists
          .where((c) => !c.isPinned)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// 即将到期的结构型清单（dueDate 在未来 7 天内）
  List<Checklist> get dueSoonStructuralChecklists =>
      _cachedDueSoonStructuralChecklists ??= structuralChecklists.where((c) {
        final days = c.daysUntilDue;
        if (days == null) return false;
        return days >= 0 && days <= 7 && !c.isAllDone;
      }).toList()
        ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

  Checklist? findById(String? id) {
    if (id == null) return null;
    try {
      return _checklists.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── 加载 ──────────────────────────────────────────────────────────

  Future<void> loadChecklists() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _checklists = await ServiceLocator.checklistDb.getAllChecklists();
      // 加载后自动检查需要重置的时态清单
      await _autoResetTemporalChecklists();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading checklists: $e');
    } finally {
      _isLoading = false;
      _invalidateCache();
      notifyListeners();
    }
  }

  // ── 自动重置时态清单 ───────────────────────────────────────────────
  //
  // 对于 repeatType = daily / weekly 的时态清单：
  // 若距上次重置已超过一个周期，自动把所有条目取消勾选，并更新 lastResetAt。
  //
  // 【会话内去重】
  // _resetIdsThisSession 记录本次 App 生命周期内已触发过重置的清单 ID。
  // 这样即使 loadChecklists() 被多次调用（如切换 Tab、热重载），
  // 同一清单不会在同一天内被反复重置。
  final Set<String> _resetIdsThisSession = {};

  Future<void> _autoResetTemporalChecklists() async {
    final now = DateTime.now();
    for (final c in _checklists) {
      if (c.checklistType != ChecklistType.temporal) continue;
      if (c.repeatType == RepeatType.none) continue;
      // 本次会话已重置过，跳过
      if (_resetIdsThisSession.contains(c.id)) continue;
      if (!_shouldReset(c, now)) continue;

      final resetItems = c.items.map((item) {
        return item.copyWith(isChecked: false, checkedAt: null);
      }).toList();

      final updated = c.copyWith(
        items: resetItems,
        lastResetAt: now,
        // 将 scheduledDate 滚动到今天（重复清单始终锚定今天）
        scheduledDate: DateTime(now.year, now.month, now.day),
        updatedAt: now,
      );
      await ServiceLocator.checklistDb.updateChecklist(updated);
      _checklists = _checklists
          .map((item) => item.id == updated.id ? updated : item)
          .toList();

      // 标记本次会话已重置，防止再次触发
      _resetIdsThisSession.add(c.id);
      debugPrint('[ChecklistProvider] 自动重置: "${c.title}" '
          'repeatType=${c.repeatType.value}');
    }
  }

  bool _shouldReset(Checklist c, DateTime now) {
    final last = c.lastResetAt;
    if (last == null) return false;
    switch (c.repeatType) {
      case RepeatType.daily:
        // 上次重置不是今天，就应该重置
        return last.year != now.year ||
            last.month != now.month ||
            last.day != now.day;
      case RepeatType.weekly:
        // 上次重置距今超过 7 天
        return now.difference(last).inDays >= 7;
      case RepeatType.none:
        return false;
    }
  }

  // ── 新建 ──────────────────────────────────────────────────────────

  Future<Checklist> addChecklist({
    required String title,
    String description = '',
    String emoji = '📋',
    String colorHex = '#5C7CFA',
    ChecklistType checklistType = ChecklistType.structural,
    ChecklistScene scene = ChecklistScene.general,
    ChecklistStyle style = ChecklistStyle.simple,
    ChecklistFunction function = ChecklistFunction.checklist,
    ChecklistInteractionMode? interactionMode,
    List<ChecklistTag> tags = const [],
    List<ChecklistItem> items = const [],
    String? aiSummary,
    DateTime? dueDate,
    DateTime? scheduledDate,
    RepeatType repeatType = RepeatType.none,
  }) async {
    final now = DateTime.now();
    // 如果调用方没有传入 interactionMode，根据 function 推断默认范式
    final resolvedMode = interactionMode ??
        ChecklistInteractionMode.fromFunction(function);
    final checklist = Checklist(
      id: const Uuid().v4(),
      title: title,
      description: description,
      emoji: emoji,
      colorHex: colorHex,
      checklistType: checklistType,
      scene: scene,
      style: style,
      function: function,
      interactionMode: resolvedMode,
      tags: tags,
      aiTaggedItemCount: 0,
      items: items,
      aiSummary: aiSummary,
      dueDate: dueDate,
      scheduledDate: scheduledDate,
      repeatType: repeatType,
      // 重复型清单首次创建时记录 lastResetAt
      lastResetAt: repeatType != RepeatType.none ? now : null,
      createdAt: now,
      updatedAt: now,
    );
    await ServiceLocator.checklistDb.insertChecklist(checklist);
    _checklists = [checklist, ..._checklists];
    _invalidateCache();
    notifyListeners();
    return checklist;
  }

  // ── 更新元信息 ────────────────────────────────────────────────────

  Future<void> updateChecklist(Checklist updated) async {
    final checklist = updated.copyWith(updatedAt: DateTime.now());
    await ServiceLocator.checklistDb.updateChecklist(checklist);
    _checklists =
        _checklists.map((c) => c.id == checklist.id ? checklist : c).toList();
    _invalidateCache();
    notifyListeners();
  }

  // ── 删除 ──────────────────────────────────────────────────────────

  Future<void> deleteChecklist(String id) async {
    await ServiceLocator.checklistDb.deleteChecklist(id);
    _checklists = _checklists.where((c) => c.id != id).toList();
    _invalidateCache();
    notifyListeners();
  }

  // ── 归档 / 恢复 ───────────────────────────────────────────────────

  Future<void> archiveChecklist(String id) async {
    final c = findById(id);
    if (c == null) return;
    await updateChecklist(c.copyWith(status: ChecklistStatus.archived));
  }

  Future<void> restoreChecklist(String id) async {
    final c = findById(id);
    if (c == null) return;
    await updateChecklist(c.copyWith(status: ChecklistStatus.active));
  }

  // ── 置顶切换 ──────────────────────────────────────────────────────

  Future<void> togglePin(String id) async {
    final c = findById(id);
    if (c == null) return;
    await updateChecklist(c.copyWith(isPinned: !c.isPinned));
  }

  // ── 时态清单专属：标记完成并归档 ──────────────────────────────────
  //
  // 时态清单全部完成后，调用此方法自动归档（不同于结构型清单的永久保留）
  Future<void> completeAndArchiveTemporal(String id) async {
    final c = findById(id);
    if (c == null) return;
    if (c.checklistType != ChecklistType.temporal) return;
    await updateChecklist(c.copyWith(status: ChecklistStatus.archived));
  }

  // ── 条目操作 ──────────────────────────────────────────────────────

  /// 新增一个条目
  Future<void> addItem(String checklistId, {
    required String title,
    String? note,
    String? groupLabel,
    String? quantity,
  }) async {
    final c = findById(checklistId);
    if (c == null) return;
    final item = ChecklistItem(
      id: const Uuid().v4(),
      title: title,
      note: note,
      groupLabel: groupLabel,
      quantity: quantity,
      sortOrder: c.items.length,
      createdAt: DateTime.now(),
    );
    final updated = c.copyWith(items: [...c.items, item]);
    await updateChecklist(updated);
    // 事后重感知：检查是否需要触发 AI ReTag
    _checkAndReTag(updated);
  }

  /// 批量添加条目（AI 生成场景）
  Future<void> addItems(String checklistId, List<ChecklistItem> newItems) async {
    final c = findById(checklistId);
    if (c == null) return;
    final startOrder = c.items.length;
    final adjusted = newItems.asMap().entries.map((e) {
      return e.value.copyWith(sortOrder: startOrder + e.key);
    }).toList();
    final updated = c.copyWith(items: [...c.items, ...adjusted]);
    await updateChecklist(updated);
    // 批量添加后针对性更强，必要时触发重感知
    _checkAndReTag(updated);
  }

  /// 勾选 / 取消勾选条目
  Future<void> toggleItem(String checklistId, String itemId) async {
    final c = findById(checklistId);
    if (c == null) return;
    final now = DateTime.now();
    final items = c.items.map((item) {
      if (item.id != itemId) return item;
      final newChecked = !item.isChecked;
      return item.copyWith(
        isChecked: newChecked,
        checkedAt: newChecked ? now : null,
      );
    }).toList();
    await updateChecklist(c.copyWith(items: items));
  }

  /// 更新条目内容
  Future<void> updateItem(String checklistId, ChecklistItem updated) async {
    final c = findById(checklistId);
    if (c == null) return;
    final items = c.items.map((item) {
      return item.id == updated.id ? updated : item;
    }).toList();
    await updateChecklist(c.copyWith(items: items));
  }

  /// 删除条目
  Future<void> removeItem(String checklistId, String itemId) async {
    final c = findById(checklistId);
    if (c == null) return;
    final items = c.items.where((item) => item.id != itemId).toList();
    await updateChecklist(c.copyWith(items: items));
  }

  /// 清空所有已勾选条目
  Future<void> clearCheckedItems(String checklistId) async {
    final c = findById(checklistId);
    if (c == null) return;
    final items = c.items.where((item) => !item.isChecked).toList();
    await updateChecklist(c.copyWith(items: items));
  }

  /// 重置所有条目（全部取消勾选）
  Future<void> resetAll(String checklistId) async {
    final c = findById(checklistId);
    if (c == null) return;
    final items = c.items.map((item) {
      return item.copyWith(isChecked: false, checkedAt: null);
    }).toList();
    await updateChecklist(c.copyWith(items: items, lastResetAt: DateTime.now()));
  }

  // ── 统计 ──────────────────────────────────────────────────────────

  int get totalCount => _checklists.length;
  int get activeCount =>
      _checklists.where((c) => c.status == ChecklistStatus.active).length;
  int get completedCount =>
      _checklists.where((c) => c.isAllDone).length;

  /// 今日待办未完成条目数（用于 Tab badge）
  ///
  /// 依赖 todayChecklists，跨天自动失效。
  int get todayPendingItemCount {
    if (_isTodayCacheValid() && _cachedTodayPendingItemCount != null) {
      return _cachedTodayPendingItemCount!;
    }
    _cachedTodayPendingItemCount =
        todayChecklists.fold<int>(0, (sum, c) => sum + c.uncheckedCount);
    return _cachedTodayPendingItemCount!;
  }

  Map<ChecklistScene, int> get sceneCounts =>
      _cachedSceneCounts ??= () {
        final map = <ChecklistScene, int>{};
        for (final c in _checklists) {
          map[c.scene] = (map[c.scene] ?? 0) + 1;
        }
        return map;
      }();

  /// 所有标签的汇总统计（用于展示标签过滤栏）
  /// key=标签文本, value=出现次数
  ///
  /// O(n·m) 开销最大的计算属性，缓存收益最高。
  Map<String, int> get tagCounts =>
      _cachedTagCounts ??= () {
        final map = <String, int>{};
        for (final c
            in _checklists.where((c) => c.status == ChecklistStatus.active)) {
          for (final label in c.allTagLabels) {
            map[label] = (map[label] ?? 0) + 1;
          }
        }
        return map;
      }();

  /// 根据标签文本过滤清单（AND 逻辑，多标签同时满足）
  List<Checklist> byTags(List<String> labels) {
    if (labels.isEmpty) return activeChecklists;
    final lower = labels.map((l) => l.toLowerCase()).toSet();
    return activeChecklists.where((c) {
      final cLabels = c.allTagLabels.map((l) => l.toLowerCase()).toSet();
      return lower.every((l) => cLabels.contains(l));
    }).toList();
  }

  // ── 标签管理 ─────────────────────────────────────────────────────

  /// 添加用户标签（自由文本，优先级最高）
  ///
  /// 如果标签已存在（不区分大小写）则忽略。
  Future<void> addUserTag(String checklistId, String label) async {
    final c = findById(checklistId);
    if (c == null) return;
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final alreadyExists = c.tags
        .any((t) => t.label.toLowerCase() == trimmed.toLowerCase());
    if (alreadyExists) return;
    final newTag = ChecklistTag(
      label: trimmed,
      source: TagSource.user,
      createdAt: DateTime.now(),
    );
    await updateChecklist(c.copyWith(tags: [...c.tags, newTag]));
  }

  /// 移除指定标签（不区分来源，不区分大小写）
  Future<void> removeTag(String checklistId, String label) async {
    final c = findById(checklistId);
    if (c == null) return;
    final newTags = c.tags
        .where((t) => t.label.toLowerCase() != label.toLowerCase())
        .toList();
    await updateChecklist(c.copyWith(tags: newTags));
  }

  // ── AI 事后重感知 ────────────────────────────────────────────────

  /// 检查是否需要触发 AI 事后重感知。
  ///
  /// 触发条件：事项数量 ≥ 上次 AI 感知时的数量 + 5。
  /// 异步后台运行，失败静默。
  void _checkAndReTag(Checklist c) {
    if (!c.needsAiReTag) return;
    // 只重感知结构型清单（时态型不需要语义标签）
    if (c.checklistType == ChecklistType.temporal) return;
    _doReTag(c);
  }

  Future<void> _doReTag(Checklist c) async {
    try {
      final result = await AiService.instance.reInferChecklistTags(
        title: c.title,
        itemTitles: c.items.map((i) => i.title).toList(),
      );
      if (result == null) return;

      // 比较新旧 AI 标签是否有实质差异
      final existingAiLabels =
          c.aiTags.map((t) => t.label.toLowerCase()).toSet();
      final newAiLabels =
          result.aiTagLabels.map((l) => l.toLowerCase()).toSet();
      final newFunction = ChecklistFunction.fromValue(result.function);
      final functionChanged = newFunction != c.function;
      final tagsChanged = existingAiLabels.length != newAiLabels.length ||
          !existingAiLabels.containsAll(newAiLabels);

      if (!functionChanged && !tagsChanged) return; // 无实质差异，不更新

      final now = DateTime.now();
      // 保留用户标签，仅替换 AI 标签
      final newAiTags = result.aiTagLabels
          .map((l) => ChecklistTag(
                label: l,
                source: TagSource.ai,
                createdAt: now,
              ))
          .toList();
      final updatedTags = [...c.userTags, ...newAiTags];

      // 重新从内存获取最新快照（防止并发覆盖）
      final fresh = findById(c.id);
      if (fresh == null) return;

      // function 变化时，如果用户没有自定义过 interactionMode（即当前 mode 等于旧 function 的默认值），
      // 则连带更新 interactionMode（范式跟局功能同步演进）
      final oldDefaultMode = ChecklistInteractionMode.fromFunction(c.function);
      final newDefaultMode = ChecklistInteractionMode.fromFunction(newFunction);
      final shouldUpdateMode = functionChanged &&
          c.interactionMode == oldDefaultMode &&
          newDefaultMode != oldDefaultMode;

      await updateChecklist(fresh.copyWith(
        function: newFunction,
        interactionMode: shouldUpdateMode ? newDefaultMode : fresh.interactionMode,
        tags: updatedTags,
        aiTaggedItemCount: fresh.items.length,
      ));
      debugPrint('[ChecklistProvider] ReTag 完成: "${c.title}" '
          '功能=${result.function} '
          '范式=${shouldUpdateMode ? newDefaultMode.value : fresh.interactionMode.value} '
          '标签=${result.aiTagLabels}');
    } catch (e) {
      debugPrint('[ChecklistProvider] ReTag 失败: $e');
    }
  }

  // ── 从模板创建清单 ────────────────────────────────────────────────

  /// 根据清单模板创建一份真实的结构型清单。
  ///
  /// 创建逻辑：
  /// 1. 将模板条目转换为 ChecklistItem（分配新 UUID + sortOrder）
  /// 2. 将模板 sceneTags 写入 userTags
  /// 3. 存入数据库，插入内存列表头部
  /// 4. 返回新建的 Checklist，供调用方跳转到详情页
  Future<Checklist> createFromTemplate(ChecklistTemplate template) async {
    const uuid = Uuid();
    final now = DateTime.now();

    // 模板条目 → ChecklistItem
    final items = template.items.asMap().entries.map((entry) {
      return entry.value.toChecklistItem(
        id: uuid.v4(),
        sortOrder: entry.key,
      );
    }).toList();

    // 模板场景标签 → userTags
    final tags = template.sceneTags
        .map((label) => ChecklistTag(
              label: label,
              source: TagSource.user,
              createdAt: now,
            ))
        .toList();

    final checklist = Checklist(
      id: uuid.v4(),
      title: template.title,
      description: template.description,
      emoji: template.emoji,
      colorHex: '#${template.colorHex}',
      checklistType: ChecklistType.structural,
      scene: template.category.scene,
      style: template.style,
      function: template.function,
      // 模板创建：interactionMode 根据 function 自动推断
      interactionMode: ChecklistInteractionMode.fromFunction(template.function),
      tags: tags,
      aiTaggedItemCount: 0,
      items: items,
      createdAt: now,
      updatedAt: now,
    );

    await ServiceLocator.checklistDb.insertChecklist(checklist);
    _checklists = [checklist, ..._checklists];
    _invalidateCache();
    notifyListeners();

    debugPrint('[ChecklistProvider] 从模板创建清单: '
        '"${template.title}" → id=${checklist.id}');
    return checklist;
  }
}

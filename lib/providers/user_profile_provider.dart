import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../platform/service_locator.dart';

// ─────────────────────────────────────────────────────────────────
//  用户档案 Provider
//  职责：加载/保存用户档案，持久化到 KV 存储
// ─────────────────────────────────────────────────────────────────

class UserProfileProvider extends ChangeNotifier {
  static const _profileKey = 'user_profile_v1';

  UserProfile _profile = const UserProfile();
  bool _isLoaded = false;

  UserProfile get profile => _profile;
  bool get isLoaded => _isLoaded;

  UserProfileProvider() {
    _load();
  }

  // ──────────────────────────────────────────────────────────
  //  加载 / 保存
  // ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final json = await ServiceLocator.kvStore.getString(_profileKey);
      if (json != null && json.isNotEmpty) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _profile = UserProfile.fromMap(map);
      }
    } catch (e) {
      debugPrint('加载用户档案失败: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final json = jsonEncode(_profile.toMap());
      await ServiceLocator.kvStore.setString(_profileKey, json);
    } catch (e) {
      debugPrint('保存用户档案失败: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  //  档案操作
  // ──────────────────────────────────────────────────────────

  /// 完整更新档案（设置页使用）
  Future<void> updateProfile({
    String? nickname,
    String? aiName,
    String? customDescription,
    List<String>? personaValues,
    List<String>? detailTagValues,
    // 旧字段兼容
    // ignore: deprecated_member_use_from_same_package
    UserIdentityType? identityType,
    String? primaryGoal,
    // ignore: deprecated_member_use_from_same_package
    UserMotivation? motivation,
    // ignore: deprecated_member_use_from_same_package
    UserBarrier? mainBarrier,
    bool? hasCompletedPortrait,
    bool clearMotivation = false,
    bool clearBarrier = false,
    // 旧 key 兼容
    List<String>? profileTagValues,
    List<String>? lifestyleTagValues,
  }) async {
    _profile = _profile.copyWith(
      nickname: nickname,
      aiName: aiName,
      customDescription: customDescription,
      personaValues: personaValues ?? profileTagValues ?? lifestyleTagValues,
      detailTagValues: detailTagValues,
      identityType: identityType,
      primaryGoal: primaryGoal,
      motivation: motivation,
      mainBarrier: mainBarrier,
      hasCompletedPortrait: hasCompletedPortrait,
      clearMotivation: clearMotivation,
      clearBarrier: clearBarrier,
    );
    notifyListeners();
    await _save();
  }

  /// 快速更新第一层：人物原型大标签（Onboarding 专用）
  Future<void> updatePersonas(List<String> values) async {
    _profile = _profile.copyWith(personaValues: values);
    notifyListeners();
    await _save();
  }

  /// 快速更新第二层：细分兴趣标签（设置页专用）
  Future<void> updateDetailTags(List<String> values) async {
    _profile = _profile.copyWith(detailTagValues: values);
    notifyListeners();
    await _save();
  }

  // ── 向后兼容别名 ────────────────────────────────────────────
  Future<void> updateProfileTags(List<String> values) =>
      updatePersonas(values);

  Future<void> updateLifestyleTags(List<String> values) =>
      updatePersonas(values);
}

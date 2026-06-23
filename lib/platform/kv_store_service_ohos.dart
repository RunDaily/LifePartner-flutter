// KV 存储服务 - HarmonyOS 实现
// 依赖：shared_preferences（标准 API）+ shared_preferences_ohos（鸿蒙平台实现）
//
// shared_preferences_ohos 通过 flutter.plugin 机制自动注册为鸿蒙平台实现，
// 因此代码只需引入标准 shared_preferences 包并调用标准 API 即可。
// 此文件与 kv_store_service_mobile.dart 逻辑完全相同。

import 'package:shared_preferences/shared_preferences.dart';
import 'kv_store_service.dart';

export 'kv_store_service.dart';

/// 工厂函数
KvStoreService createKvStore() => OhosKvStoreService();

/// HarmonyOS KV 存储实现
/// shared_preferences_ohos 已通过插件机制自动注册，无需手动处理
class OhosKvStoreService implements KvStoreService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<int?> getInt(String key) async {
    final prefs = await _getPrefs();
    return prefs.getInt(key);
  }

  @override
  Future<void> setInt(String key, int value) async {
    final prefs = await _getPrefs();
    await prefs.setInt(key, value);
  }

  @override
  Future<String?> getString(String key) async {
    final prefs = await _getPrefs();
    return prefs.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    final prefs = await _getPrefs();
    await prefs.setString(key, value);
  }

  @override
  Future<bool?> getBool(String key) async {
    final prefs = await _getPrefs();
    return prefs.getBool(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(key, value);
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await _getPrefs();
    await prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.clear();
  }
}

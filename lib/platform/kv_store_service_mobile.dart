// KV 存储服务 - Android / iOS 实现
// 依赖：shared_preferences
import 'package:shared_preferences/shared_preferences.dart';
import 'kv_store_service.dart';

export 'kv_store_service.dart';

/// 工厂函数 - 创建当前平台的 KV 存储实例
/// 由 DiaryServiceLocator 调用，外部代码只依赖抽象接口
KvStoreService createKvStore() => MobileKvStoreService();

/// Android / iOS 实现（shared_preferences）
class MobileKvStoreService implements KvStoreService {
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

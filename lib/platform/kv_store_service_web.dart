// KV 存储服务 - Web 实现（内存存储，仅供预览）
// Web 平台不支持 shared_preferences（需要额外插件），使用内存 Map 模拟。
import 'kv_store_service.dart';

export 'kv_store_service.dart';

/// 工厂函数
KvStoreService createKvStore() => WebKvStoreService();

/// Web 实现（内存存储）
class WebKvStoreService implements KvStoreService {
  final Map<String, dynamic> _store = {};

  @override
  Future<int?> getInt(String key) async => _store[key] as int?;

  @override
  Future<void> setInt(String key, int value) async => _store[key] = value;

  @override
  Future<String?> getString(String key) async => _store[key] as String?;

  @override
  Future<void> setString(String key, String value) async =>
      _store[key] = value;

  @override
  Future<bool?> getBool(String key) async => _store[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _store[key] = value;

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();
}

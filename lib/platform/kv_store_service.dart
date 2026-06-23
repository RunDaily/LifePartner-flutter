/// KV 键值存储抽象接口
/// 通过条件导入自动选择平台实现：
///   - Android / iOS  → kv_store_service_mobile.dart（shared_preferences）
///   - HarmonyOS      → kv_store_service_ohos.dart（shared_preferences_ohos）
library;

export 'kv_store_service_mobile.dart'
    if (dart.library.ffi) 'kv_store_service_mobile.dart';

/// 统一的 KV 存储抽象基类，所有平台实现必须继承此类
abstract class KvStoreService {
  /// 读取整数
  Future<int?> getInt(String key);

  /// 写入整数
  Future<void> setInt(String key, int value);

  /// 读取字符串
  Future<String?> getString(String key);

  /// 写入字符串
  Future<void> setString(String key, String value);

  /// 读取布尔值
  Future<bool?> getBool(String key);

  /// 写入布尔值
  Future<void> setBool(String key, bool value);

  /// 删除键
  Future<void> remove(String key);

  /// 清空所有
  Future<void> clear();
}

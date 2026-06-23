import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'ai_service.dart';

// ─────────────────────────────────────────────────────────────────
//  AI 调试日志服务
//
//  职责：
//  1. 将每次 AI 对话完成后的 AiDebugTokenInfo 序列化为 JSON，
//     追加写入本地 ai_debug_log.jsonl（每行一条 JSON，JSONL 格式）。
//  2. 读取已保存的日志条目（分页加载，最新在前）。
//  3. 支持清空日志文件。
//
//  日志文件位置：<App Documents Dir>/ai_debug/ai_debug_log.jsonl
//  仅在 kDebugMode == true 时生效，Release 版本直接 no-op。
// ─────────────────────────────────────────────────────────────────

class AiDebugLogService {
  AiDebugLogService._();
  static final AiDebugLogService instance = AiDebugLogService._();

  static const _dirName = 'ai_debug';
  static const _fileName = 'ai_debug_log.jsonl';

  File? _logFile;

  // ── 初始化（懒加载，首次调用时自动执行）───────────────────────

  Future<File> _getLogFile() async {
    if (_logFile != null) return _logFile!;
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, _dirName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _logFile = File(p.join(dir.path, _fileName));
    return _logFile!;
  }

  // ── 写入一条调试记录 ─────────────────────────────────────────

  /// 将 [info] 序列化为一行 JSON 并追加写入日志文件。
  /// 仅在 kDebugMode 下有效；异常不上抛（调试日志不应影响主流程）。
  Future<void> appendLog(AiDebugTokenInfo info) async {
    if (!kDebugMode) return;
    try {
      final file = await _getLogFile();
      final json = _infoToJson(info);
      final line = jsonEncode(json);
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('[AiDebugLogService] 写入日志失败: $e');
    }
  }

  // ── 读取日志（最新在前，支持分页）────────────────────────────

  /// 读取全部日志条目，按时间倒序（最新在前）返回。
  /// [limit] 限制最多返回条数（0 = 全部）。
  Future<List<AiDebugLogEntry>> readLogs({int limit = 0}) async {
    if (!kDebugMode) return [];
    try {
      final file = await _getLogFile();
      if (!file.existsSync()) return [];

      final lines = await file.readAsLines();
      final entries = <AiDebugLogEntry>[];

      for (final line in lines.reversed) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          entries.add(AiDebugLogEntry.fromJson(json));
        } catch (_) {
          // 跳过损坏的行
        }
        if (limit > 0 && entries.length >= limit) break;
      }

      return entries;
    } catch (e) {
      debugPrint('[AiDebugLogService] 读取日志失败: $e');
      return [];
    }
  }

  /// 返回日志文件路径（供 UI 展示）
  Future<String> getLogFilePath() async {
    final file = await _getLogFile();
    return file.path;
  }

  /// 返回日志文件大小（字节），文件不存在时返回 0
  Future<int> getLogFileSizeBytes() async {
    try {
      final file = await _getLogFile();
      if (!file.existsSync()) return 0;
      return file.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  /// 清空所有日志
  Future<void> clearLogs() async {
    if (!kDebugMode) return;
    try {
      final file = await _getLogFile();
      if (file.existsSync()) {
        await file.writeAsString('', flush: true);
      }
    } catch (e) {
      debugPrint('[AiDebugLogService] 清空日志失败: $e');
    }
  }

  // ── 序列化 / 反序列化 ─────────────────────────────────────────

  static Map<String, dynamic> _infoToJson(AiDebugTokenInfo info) {
    return {
      'startTime': info.startTime.toIso8601String(),
      'endTime': info.endTime?.toIso8601String(),
      'elapsedMs': info.elapsedMs,
      // Token 估算值
      'systemPromptTokens': info.systemPromptTokens,
      'historyTokens': info.historyTokens,
      'userQuestionTokens': info.userQuestionTokens,
      'totalInputTokens': info.totalInputTokens,
      'maxOutputTokens': info.maxOutputTokens,
      'outputTokens': info.outputTokens,
      // API 实际值（可能为 null）
      'apiPromptTokens': info.apiPromptTokens,
      'apiCompletionTokens': info.apiCompletionTokens,
      'apiTotalTokens': info.apiTotalTokens,
      // 日记注入信息
      'diaryContextMode': info.diaryContextMode,
      'injectedMomentCount': info.injectedMomentCount,
      'totalMomentCount': info.totalMomentCount,
      'maxHistoryMessages': info.maxHistoryMessages,
      // 内容文本
      'userQuestion': info.userQuestion,
      'systemPromptContent': info.systemPromptContent,
      'responseContent': info.responseContent,
    };
  }
}

// ─────────────────────────────────────────────────────────────────
//  日志条目模型（从 JSONL 文件读取还原）
// ─────────────────────────────────────────────────────────────────

class AiDebugLogEntry {
  final DateTime startTime;
  final DateTime? endTime;
  final int elapsedMs;

  // Token 估算
  final int systemPromptTokens;
  final int historyTokens;
  final int userQuestionTokens;
  final int totalInputTokens;
  final int maxOutputTokens;
  final int outputTokens;

  // API 实际值
  final int? apiPromptTokens;
  final int? apiCompletionTokens;
  final int? apiTotalTokens;

  // 日记注入信息
  final String diaryContextMode;
  final int injectedMomentCount;
  final int totalMomentCount;
  final int maxHistoryMessages;

  // 内容文本
  final String userQuestion;
  final String systemPromptContent;
  final String responseContent;

  const AiDebugLogEntry({
    required this.startTime,
    this.endTime,
    required this.elapsedMs,
    required this.systemPromptTokens,
    required this.historyTokens,
    required this.userQuestionTokens,
    required this.totalInputTokens,
    required this.maxOutputTokens,
    required this.outputTokens,
    this.apiPromptTokens,
    this.apiCompletionTokens,
    this.apiTotalTokens,
    required this.diaryContextMode,
    required this.injectedMomentCount,
    required this.totalMomentCount,
    required this.maxHistoryMessages,
    required this.userQuestion,
    required this.systemPromptContent,
    required this.responseContent,
  });

  factory AiDebugLogEntry.fromJson(Map<String, dynamic> json) {
    return AiDebugLogEntry(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      systemPromptTokens: (json['systemPromptTokens'] as num?)?.toInt() ?? 0,
      historyTokens: (json['historyTokens'] as num?)?.toInt() ?? 0,
      userQuestionTokens: (json['userQuestionTokens'] as num?)?.toInt() ?? 0,
      totalInputTokens: (json['totalInputTokens'] as num?)?.toInt() ?? 0,
      maxOutputTokens: (json['maxOutputTokens'] as num?)?.toInt() ?? 0,
      outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
      apiPromptTokens: (json['apiPromptTokens'] as num?)?.toInt(),
      apiCompletionTokens: (json['apiCompletionTokens'] as num?)?.toInt(),
      apiTotalTokens: (json['apiTotalTokens'] as num?)?.toInt(),
      diaryContextMode: json['diaryContextMode'] as String? ?? '',
      injectedMomentCount: (json['injectedMomentCount'] as num?)?.toInt() ?? 0,
      totalMomentCount: (json['totalMomentCount'] as num?)?.toInt() ?? 0,
      maxHistoryMessages: (json['maxHistoryMessages'] as num?)?.toInt() ?? 0,
      userQuestion: json['userQuestion'] as String? ?? '',
      systemPromptContent: json['systemPromptContent'] as String? ?? '',
      responseContent: json['responseContent'] as String? ?? '',
    );
  }

  /// 是否有 API 实际 Token 数据
  bool get hasApiTokens => apiTotalTokens != null;

  /// 输入 Token（优先 API 实际值）
  int get inputTokens => apiPromptTokens ?? totalInputTokens;

  /// 输出 Token（优先 API 实际值）
  int get outputTokensFinal => apiCompletionTokens ?? outputTokens;

  /// 合计 Token（优先 API 实际值）
  int get totalTokens => apiTotalTokens ?? (inputTokens + outputTokensFinal);

  /// 格式化时间字符串（用于列表显示）
  String get timeLabel {
    final t = startTime;
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  /// 耗时字符串
  String get elapsedLabel => elapsedMs < 1000
      ? '${elapsedMs}ms'
      : '${(elapsedMs / 1000).toStringAsFixed(1)}s';
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/record_provider.dart';
import '../models/record.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  AI 调试页面
//  显示当前 Record 数据概览，用于开发调试
// ─────────────────────────────────────────────────────────────────

class AiDebugScreen extends StatelessWidget {
  const AiDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recordProvider = context.watch<RecordProvider>();

    final records = recordProvider.allRecords;

    // 按类型分组统计
    final typeStats = <RecordType, int>{};
    for (final r in records) {
      typeStats[r.type] = (typeStats[r.type] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('数据调试'),
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 统计概览
          _buildSection(
            title: '记录总览 (${records.length} 条)',
            isDark: isDark,
            child: typeStats.isEmpty
                ? Text(
                    '暂无记录',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF666666)
                          : const Color(0xFFAA99CC),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: typeStats.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(entry.key.emoji,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFE0D4FF)
                                      : const Color(0xFF2D2040),
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value} 条',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 16),

          // 最近记录
          _buildSection(
            title: '最近记录（前10条）',
            isDark: isDark,
            child: records.isEmpty
                ? Text(
                    '暂无内容',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF666666)
                          : const Color(0xFFAA99CC),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: records.take(10).map((r) {
                      final preview = r.title.isNotEmpty
                          ? r.title
                          : r.content.isNotEmpty
                              ? r.content
                              : '（无内容）';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(r.type.emoji,
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                preview,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFFCDBFE8)
                                      : const Color(0xFF3D3050),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${r.createdAt.month}/${r.createdAt.day}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF666666)
                                    : const Color(0xFFAA99CC),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF333333)
              : const Color(0xFFEEE8FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

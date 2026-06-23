#!/usr/bin/env python3
"""在 plan_screen.dart 末尾追加 _PlanScheduleBanner widget"""

banner_code = '''
// ─────────────────────────────────────────────────────────────────
//  _PlanScheduleBanner —— 规划模块内的日程入口横条
//
//  与清单模块的 _ScheduleEntryBanner 设计对称，
//  强调「规划 → 执行调度」的跳转语义
// ─────────────────────────────────────────────────────────────────

class _PlanScheduleBanner extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  const _PlanScheduleBanner({
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withValues(alpha: isDark ? 0.2 : 0.12),
              primary.withValues(alpha: isDark ? 0.08 : 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary.withValues(alpha: isDark ? 0.28 : 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('\u{1F4C5}', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u65e5\u7a0b',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1410),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '\u67e5\u770b\u5e76\u5b89\u6392\u6267\u884c\u65e5\u7a0b',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : const Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: primary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
'''

fpath = 'lib/screens/plan_screen.dart'
with open(fpath, 'r') as f:
    content = f.read()

if '_PlanScheduleBanner' in content:
    print('SKIP: already exists')
else:
    content = content + banner_code
    with open(fpath, 'w') as f:
        f.write(content)
    print('SUCCESS: appended _PlanScheduleBanner')

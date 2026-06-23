import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'today_screen.dart';
import 'space_screen.dart';
import 'quick_capture_sheet.dart';

// ─────────────────────────────────────────────────────────────────
//  MainShell — 底部导航主框架（v2）
//
//  3 Tab：今天  |  ＋（快速捕获）|  空间
//
//  「我」的入口迁移至 TodayScreen AppBar 左上角圆形头像区。
//  「空间」Tab 汇聚所有核心模块：日记 / 清单 / 笔记收藏 / 活动 / 项目。
// ─────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> with TickerProviderStateMixin {
  // 只有 2 个真实页面（今天 / 空间），中间 ＋ 不算页面
  int _currentIndex = 0; // 0=今天, 1=空间

  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void switchTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
    HapticFeedback.lightImpact();
  }

  Future<void> _openQuickCapture() async {
    HapticFeedback.mediumImpact();
    await QuickCaptureSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          TodayScreen(),
          SpaceScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final palette = WeeklyTheme.getLightPalette();
    final activeColor = isDark ? AppColors.darkPrimary : palette.primary;
    final inactiveColor =
        isDark ? const Color(0xFF666666) : const Color(0xFFBBBBBB);
    final borderColor = isDark
        ? activeColor.withValues(alpha: 0.15)
        : activeColor.withValues(alpha: 0.1);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              // ── 今天 Tab ────────────────────────────────────
              _NavItem(
                index: 0,
                currentIndex: _currentIndex,
                icon: Icons.wb_sunny_outlined,
                activeIcon: Icons.wb_sunny_rounded,
                label: '今天',
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => switchTab(0),
              ),
              // ── 中间 ＋ 按钮（快速捕获，不是 Tab）─────────
              _CenterAddButton(
                activeColor: activeColor,
                onTap: _openQuickCapture,
              ),
              // ── 空间 Tab ─────────────────────────────────
              _NavItem(
                index: 1,
                currentIndex: _currentIndex,
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: '空间',
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => switchTab(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 普通导航项 ────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                size: 22,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? activeColor : inactiveColor,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 中间 ＋ 按钮 ──────────────────────────────────────────────────
class _CenterAddButton extends StatelessWidget {
  final Color activeColor;
  final VoidCallback onTap;

  const _CenterAddButton({
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    activeColor,
                    activeColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

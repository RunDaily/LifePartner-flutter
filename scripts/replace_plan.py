#!/usr/bin/env python3
"""临时脚本：在 plan_screen.dart 中注入日程入口 Banner"""
import sys

fpath = 'lib/screens/plan_screen.dart'
with open(fpath, 'r') as f:
    content = f.read()

old = (
    "            bottom: TabBar(\n"
    "              controller: _tabController,\n"
    "              labelColor: isDark ? AppColors.darkPrimary : palette.primary,\n"
    "              unselectedLabelColor:\n"
    "                  isDark ? const Color(0xFF888888) : const Color(0xFFBBBBBB),\n"
    "              indicatorColor: isDark ? AppColors.darkPrimary : palette.primary,\n"
    "              indicatorSize: TabBarIndicatorSize.label,\n"
    "              labelStyle:\n"
    "                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),\n"
    "              tabs: const [\n"
    "                Tab(text: '\u76ee\u6807'),\n"
    "                Tab(text: '\u9879\u76ee'),\n"
    "                Tab(text: '\u4e60\u60ef'),\n"
    "              ],\n"
    "            ),"
)

new = (
    "            bottom: PreferredSize(\n"
    "              preferredSize: const Size.fromHeight(100),\n"
    "              child: Column(\n"
    "                mainAxisSize: MainAxisSize.min,\n"
    "                children: [\n"
    "                  // \u65e5\u7a0b\u5165\u53e3\u6a2a\u6761\n"
    "                  _PlanScheduleBanner(\n"
    "                    isDark: isDark,\n"
    "                    primary: isDark ? AppColors.darkPrimary : palette.primary,\n"
    "                    onTap: () => Navigator.push(\n"
    "                      ctx,\n"
    "                      MaterialPageRoute(builder: (_) => const ScheduleScreen()),\n"
    "                    ),\n"
    "                  ),\n"
    "                  // Tab \u680f\n"
    "                  TabBar(\n"
    "                    controller: _tabController,\n"
    "                    labelColor: isDark ? AppColors.darkPrimary : palette.primary,\n"
    "                    unselectedLabelColor:\n"
    "                        isDark ? const Color(0xFF888888) : const Color(0xFFBBBBBB),\n"
    "                    indicatorColor: isDark ? AppColors.darkPrimary : palette.primary,\n"
    "                    indicatorSize: TabBarIndicatorSize.label,\n"
    "                    labelStyle:\n"
    "                        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),\n"
    "                    tabs: const [\n"
    "                      Tab(text: '\u76ee\u6807'),\n"
    "                      Tab(text: '\u9879\u76ee'),\n"
    "                      Tab(text: '\u4e60\u60ef'),\n"
    "                    ],\n"
    "                  ),\n"
    "                ],\n"
    "              ),\n"
    "            ),"
)

if old in content:
    content = content.replace(old, new, 1)
    with open(fpath, 'w') as f:
        f.write(content)
    print('SUCCESS')
else:
    print('ERROR: pattern not found')
    # Print first 50 chars around "bottom: TabBar" for debugging
    idx = content.find('bottom: TabBar')
    if idx >= 0:
        print(repr(content[max(0, idx-10):idx+100]))
    sys.exit(1)

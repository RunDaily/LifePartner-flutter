import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  我的画像设置页 v3
//
//  布局：
//  ① 顶部 Banner（画像完成度）
//  ② 基本信息（昵称 + AI名字）
//  ③ 我是谁 [第一层·人物原型，10个大标签]
//  ④ 我的兴趣 [第二层·细分标签，按子组展开]
//  ⑤ 补充说明 [自由文本]
// ─────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nicknameCtrl;
  late TextEditingController _aiNameCtrl;
  late TextEditingController _descCtrl;

  late Set<String> _personaValues;
  late Set<String> _detailTagValues;

  bool _detailExpanded = false;
  bool _isSaving = false;
  bool _hasChanges = false;

  late final AnimationController _expandAnim;
  late final Animation<double> _expandFade;

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProfileProvider>().profile;
    _nicknameCtrl = TextEditingController(text: profile.nickname);
    _aiNameCtrl = TextEditingController(text: profile.aiName);
    _descCtrl = TextEditingController(text: profile.customDescription);
    _personaValues = Set.from(profile.personaValues);
    _detailTagValues = Set.from(profile.detailTagValues);

    _nicknameCtrl.addListener(_onChanged);
    _aiNameCtrl.addListener(_onChanged);
    _descCtrl.addListener(_onChanged);

    _expandAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandFade = CurvedAnimation(
      parent: _expandAnim,
      curve: Curves.easeInOut,
    );
  }

  void _onChanged() => setState(() => _hasChanges = true);

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _aiNameCtrl.dispose();
    _descCtrl.dispose();
    _expandAnim.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final aiName = _aiNameCtrl.text.trim().isNotEmpty
        ? _aiNameCtrl.text.trim()
        : '小瞬';
    await context.read<UserProfileProvider>().updateProfile(
          nickname: _nicknameCtrl.text.trim(),
          aiName: aiName,
          customDescription: _descCtrl.text.trim(),
          personaValues: _personaValues.toList(),
          detailTagValues: _detailTagValues.toList(),
        );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _hasChanges = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已保存 ✓'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 1),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _togglePersona(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_personaValues.contains(value)) {
        _personaValues.remove(value);
      } else {
        _personaValues.add(value);
      }
      _hasChanges = true;
    });
  }

  void _toggleDetail(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_detailTagValues.contains(value)) {
        _detailTagValues.remove(value);
      } else {
        _detailTagValues.add(value);
      }
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('我的画像'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : Text(
                      '保存',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ① 画像完成度 Banner
            _ProfileBanner(
              isDark: isDark,
              personaCount: _personaValues.length,
              detailCount: _detailTagValues.length,
            ),
            const SizedBox(height: 16),

            // ② 基本信息
            _SectionCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    icon: Icons.person_outline,
                    title: '基本信息',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _InputField(
                    label: '你的昵称',
                    controller: _nicknameCtrl,
                    hint: 'AI 会用这个名字称呼你',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _InputField(
                    label: 'AI 助手的名字',
                    controller: _aiNameCtrl,
                    hint: '默认叫「小瞬」，随你改',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ③ 第一层：人物原型大标签
            _SectionCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SectionTitle(
                        icon: Icons.person_pin_outlined,
                        title: '我是谁',
                        isDark: isDark,
                      ),
                      const Spacer(),
                      if (_personaValues.isNotEmpty)
                        _CountBadge(
                          count: _personaValues.length,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '选择最符合你的标签，AI 会据此调整推荐风格',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white38
                          : const Color(0xFFAAAAAA),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 10个大标签，两列网格
                  _PersonaGrid(
                    selectedValues: _personaValues,
                    isDark: isDark,
                    onToggle: _togglePersona,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ④ 第二层：细分兴趣标签（可展开）
            _SectionCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行（点击展开）
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _detailExpanded = !_detailExpanded);
                      if (_detailExpanded) {
                        _expandAnim.forward();
                      } else {
                        _expandAnim.reverse();
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        _SectionTitle(
                          icon: Icons.interests_outlined,
                          title: '更多兴趣标签',
                          isDark: isDark,
                        ),
                        const Spacer(),
                        if (_detailTagValues.isNotEmpty)
                          _CountBadge(
                            count: _detailTagValues.length,
                            color: const Color(0xFF20C997),
                          ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _detailExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: isDark
                                ? Colors.white38
                                : const Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '让 AI 更了解你的具体兴趣和当下状态',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white38
                          : const Color(0xFFAAAAAA),
                    ),
                  ),

                  // 展开内容
                  SizeTransition(
                    sizeFactor: _expandFade,
                    axisAlignment: -1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _DetailTagsPanel(
                        selectedValues: _detailTagValues,
                        isDark: isDark,
                        onToggle: _toggleDetail,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ⑤ 补充说明
            _SectionCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    icon: Icons.edit_note_rounded,
                    title: '补充说明',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '有什么特殊情况想让 AI 知道？',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white38
                          : const Color(0xFFAAAAAA),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InputField(
                    label: '',
                    controller: _descCtrl,
                    hint: '例如：我目前孕20周、有乳糖不耐受、正在戒糖…',
                    isDark: isDark,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 保存按钮
            if (_hasChanges)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          '保存',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  顶部画像完成度 Banner
// ─────────────────────────────────────────────────────────────────

class _ProfileBanner extends StatelessWidget {
  final bool isDark;
  final int personaCount;
  final int detailCount;

  const _ProfileBanner({
    required this.isDark,
    required this.personaCount,
    required this.detailCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = personaCount + detailCount;
    final hasProfile = total > 0;

    String statusText;
    String emoji;
    if (personaCount == 0) {
      statusText = '选择标签后，AI 推荐会更贴合你的生活';
      emoji = '🎯';
    } else if (personaCount < 3) {
      statusText = '已选 $personaCount 个身份标签，再多选几个兴趣试试？';
      emoji = '✨';
    } else {
      statusText = '画像已较完整，AI 对你的了解越来越深';
      emoji = '🧠';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasProfile
              ? [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.04),
                ]
              : [
                  (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.02)),
                  (isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.black.withValues(alpha: 0.01)),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasProfile
              ? AppColors.primary.withValues(alpha: 0.2)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasProfile ? '我的 AI 画像' : '开始建立你的画像',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1410),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF888888),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (total > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$total 个标签',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  第一层：人物原型大标签网格（2列）
// ─────────────────────────────────────────────────────────────────

class _PersonaGrid extends StatelessWidget {
  final Set<String> selectedValues;
  final bool isDark;
  final ValueChanged<String> onToggle;

  const _PersonaGrid({
    required this.selectedValues,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final archetypes = PersonaArchetype.values;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: archetypes.length,
      itemBuilder: (_, i) {
        final p = archetypes[i];
        final isSelected = selectedValues.contains(p.value);
        return _PersonaCard(
          archetype: p,
          isSelected: isSelected,
          isDark: isDark,
          onTap: () => onToggle(p.value),
        );
      },
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final PersonaArchetype archetype;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PersonaCard({
    required this.archetype,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.07)),
            width: isSelected ? 1.5 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Text(archetype.emoji,
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                archetype.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.85)
                          : const Color(0xFF333333)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  第二层：细分兴趣标签面板（按子组分组）
// ─────────────────────────────────────────────────────────────────

class _DetailTagsPanel extends StatelessWidget {
  final Set<String> selectedValues;
  final bool isDark;
  final ValueChanged<String> onToggle;

  const _DetailTagsPanel({
    required this.selectedValues,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: DetailTagGroup.values.map((group) {
        final tags = DetailTags.byGroup(group);
        final selectedInGroup =
            tags.where((t) => selectedValues.contains(t.value)).length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 子组标题
              Row(
                children: [
                  Text(group.emoji,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    group.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white54
                          : const Color(0xFF888888),
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (selectedInGroup > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20C997)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$selectedInGroup',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF20C997),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              // 标签 Wrap
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: tags.map((tag) {
                  final isSelected = selectedValues.contains(tag.value);
                  return _DetailChip(
                    tag: tag,
                    isSelected: isSelected,
                    isDark: isDark,
                    onTap: () => onToggle(tag.value),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final DetailTag tag;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _DetailChip({
    required this.tag,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  static const _accent = Color(0xFF20C997);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? _accent
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? _accent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.07)),
            width: isSelected ? 0 : 0.7,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tag.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              tag.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFF333333)),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 3),
              const Icon(Icons.check_rounded,
                  size: 12, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  通用组件
// ─────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _SectionCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark
                ? const Color(0xFFE0D4FF)
                : const Color(0xFF2D2040),
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '已选 $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final int maxLines;

  const _InputField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.isDark,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? const Color(0xFFAA99CC)
                  : const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1625)
                : const Color(0xFFFAF8FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF3D3050)
                  : const Color(0xFFEDE7FF),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: maxLines == 1 ? 1 : 2,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? const Color(0xFFCDBFE8)
                  : const Color(0xFF3D3050),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF4A3D6B)
                    : const Color(0xFFCDBFE8),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

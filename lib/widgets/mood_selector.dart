import 'package:flutter/material.dart';
import '../models/record.dart';
import '../theme/app_theme.dart';

class MoodSelector extends StatelessWidget {
  final String selectedMood;
  final ValueChanged<String> onMoodSelected;
  final bool compact;

  const MoodSelector({
    super.key,
    required this.selectedMood,
    required this.onMoodSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: MoodType.values.map((mood) {
          final isSelected = selectedMood == mood.value;
          return GestureDetector(
            onTap: () => onMoodSelected(mood.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(
                        color: AppColors.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: Text(
                mood.emoji,
                style: TextStyle(
                  fontSize: isSelected ? 24 : 20,
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今天心情如何？',
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: MoodType.values.map((mood) {
            final isSelected = selectedMood == mood.value;
            final moodColor = AppColors.getMoodColor(mood.value);
            return GestureDetector(
              onTap: () => onMoodSelected(mood.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? moodColor.withValues(alpha: 0.2)
                      : isDark
                          ? const Color(0xFF252525)
                          : const Color(0xFFFFF0DC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? moodColor : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: moodColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mood.emoji,
                      style: TextStyle(
                        fontSize: isSelected ? 28 : 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mood.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? moodColor
                            : isDark
                                ? const Color(0xFFAA99CC)
                                : const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

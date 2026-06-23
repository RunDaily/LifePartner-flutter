import 'package:intl/intl.dart';

class DiaryDateUtils {
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return '今天 ${DateFormat('HH:mm').format(date)}';
    } else if (dateOnly == yesterday) {
      return '昨天 ${DateFormat('HH:mm').format(date)}';
    } else if (date.year == now.year) {
      return DateFormat('MM月dd日 HH:mm').format(date);
    } else {
      return DateFormat('yyyy年MM月dd日').format(date);
    }
  }

  static String formatDateOnly(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year) {
      return DateFormat('MM月dd日').format(date);
    } else {
      return DateFormat('yyyy年MM月dd日').format(date);
    }
  }

  static String formatFullDate(DateTime date) {
    return DateFormat('yyyy年MM月dd日 EEEE HH:mm', 'zh_CN').format(date);
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('yyyy年MM月').format(date);
  }

  static String formatWeekday(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday - 1];
  }

  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '深夜了，注意休息 🌙';
    if (hour < 12) return '早上好，美好的一天开始了 ☀️';
    if (hour < 14) return '午安，记录此刻的心情 🌤️';
    if (hour < 18) return '下午好，分享今天的故事 🌈';
    if (hour < 22) return '晚上好，回顾一天的点滴 🌙';
    return '夜深了，写下今天的感想 ✨';
  }
}

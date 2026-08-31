class TimeUtils {

  //  FORMAT CHAT MESSAGE TIME


  static String formatChatTime(DateTime dateTime) {
    final now = DateTime.now();

    final isToday = _isSameDay(now, dateTime);
    final isYesterday =
        _isSameDay(now.subtract(const Duration(days: 1)), dateTime);

    final time =
        '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';

    if (isToday) {
      return time;
    } else if (isYesterday) {
      return 'أمس $time';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }


  //  TIME AGO FORMAT


  static String timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }


  //  FULL DATE FORMAT

  static String formatFullDate(DateTime dateTime) {
    return '${dateTime.day} ${_monthName(dateTime.month)} ${dateTime.year}';
  }


  //  CHECK MINUTES PASSED


  static bool hasMinutesPassed(
    DateTime from,
    int minutes,
  ) {
    final difference = DateTime.now().difference(from);
    return difference.inMinutes >= minutes;
  }


  //  IS FIRST OPEN TODAY


  static bool isNewDay(DateTime? lastTime) {
    if (lastTime == null) return true;

    final now = DateTime.now();
    return !_isSameDay(now, lastTime);
  }


  //  SAME DAY CHECK


  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }


  //  TWO DIGITS HELPER


  static String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }


  //  MONTH NAME AR


  static String _monthName(int month) {
    const months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    return months[month];
  }
}
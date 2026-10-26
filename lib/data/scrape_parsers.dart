import 'models.dart';

/// تفسير نصوص صفحات الخدمات كما يقرؤها المتصفح المخفي. الدوال منفصلة عن
/// الشبكة حتى يمكن اختبارها بنصوص الصفحات مباشرة.
class ScrapeParsers {
  static const _weekdays = ['الاحد', 'الأحد', 'الاثنين', 'الإثنين', 'الثلاثاء', 'الاربعاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

  static List<String> lines(String text) =>
      text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  /// التقويم يأتي بعد أسماء أيام الأسبوع: رقم اليوم ثم وقت الدخول ثم وقت
  /// الخروج، و«-:-» تعني عدم وجود بصمة، و N تعني عطلة. تُقرأ الأيام بترتيبها
  /// 1، 2، 3... حتى لا تختلط بأرقام أخرى في الصفحة مثل قائمة الأشهر.
  static List<AttendanceDay> attendance(String text, int year, int month) {
    final tokens = lines(text).expand((l) => l.split(RegExp(r'\s+'))).where((t) => t.isNotEmpty).toList();
    var start = -1;
    for (var i = 0; i < tokens.length; i++) {
      if (_weekdays.contains(tokens[i])) start = i + 1;
    }
    if (start < 0) return const [];
    final last = DateTime(year, month + 1, 0).day;
    final time = RegExp(r'^(\d{1,2}):(\d{1,2})$');
    final days = <AttendanceDay>[];
    var expect = 1;
    List<String>? cur;
    void close() {
      if (cur == null) return;
      final times = cur.where(time.hasMatch).map((t) {
        final m = time.firstMatch(t)!;
        return '${m[1]}:${m[2]!.padLeft(2, '0')}';
      }).toList();
      days.add(AttendanceDay(
        DateTime(year, month, expect - 1),
        checkIn: times.isNotEmpty ? times[0] : null,
        checkOut: times.length > 1 ? times[1] : null,
        holiday: cur.any((t) => t.toUpperCase() == 'N'),
      ));
    }

    for (final t in tokens.skip(start)) {
      if (int.tryParse(t) == expect && expect <= last) {
        close();
        cur = [];
        expect++;
      } else if (cur != null) {
        if (int.tryParse(t) != null && !time.hasMatch(t)) break;
        cur.add(t);
      }
    }
    close();
    return days;
  }

  /// صفحة النقاط سطور «البند ثم الرقم» ومعها المجموع.
  static HousingPoints? points(String text) {
    final ls = lines(text);
    final items = <String, int>{};
    int? total;
    void add(String label, int v) {
      if (label.contains('المجموع')) {
        total = v;
      } else if (!items.containsKey(label)) {
        items[label] = v;
      }
    }

    final num = RegExp(r'^\d+$');
    final inline = RegExp(r'^(\D+?)\s+(\d+)$');
    for (var i = 0; i < ls.length; i++) {
      final m = inline.firstMatch(ls[i]);
      if (m != null) {
        add(m[1]!.trim(), int.parse(m[2]!));
      } else if (!num.hasMatch(ls[i]) && i + 1 < ls.length && num.hasMatch(ls[i + 1])) {
        add(ls[i], int.parse(ls[i + 1]));
        i++;
      }
    }
    if (items.isEmpty && total == null) return null;
    return HousingPoints(items, max: null, reportedTotal: total);
  }
}

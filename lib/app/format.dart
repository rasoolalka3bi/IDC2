import 'package:intl/intl.dart';

const arabicMonths = [
  'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
  'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول',
];

const arabicWeekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String monthName(int m) => arabicMonths[(m - 1) % 12];

String monthYear(int y, int m) => '${monthName(m)} $y';

final _money = NumberFormat('#,##0', 'en');

String money(num v) => _money.format(v);

String dateStr(DateTime? d) => d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

String dayMonth(DateTime d) => '${d.day} ${monthName(d.month)}';

/// صيغة "منذ ..." بالعربية كما في التطبيق الأصلي.
String timeAgo(DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${_unit(diff.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق')}';
  if (diff.inHours < 24) return 'منذ ${_unit(diff.inHours, 'ساعة', 'ساعتين', 'ساعات')}';
  if (diff.inDays == 1) return 'أمس';
  if (diff.inDays < 30) return 'منذ ${_unit(diff.inDays, 'يوم', 'يومين', 'أيام')}';
  return dateStr(d);
}

String _unit(int n, String one, String two, String few) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n <= 10) return '$n $few';
  return '$n $one';
}

String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return 'صباح الخير';
  return 'مساء الخير';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:idc_app/data/scrape_parsers.dart';

void main() {
  test('الحضور يُقرأ بعد أسماء الأيام ولا يختلط بقائمة الأشهر', () {
    const text = '''
📅 الحضور الإلكتروني
2025
2026
1
2
3
10
11
12
عرض
/ /
تشرين الاول 2026
الاحد	الاثنين	الثلاثاء	الاربعاء	الخميس	الجمعة	السبت
1
N
2
N
3
N
4
7:25
-:-
5
7:23
14:30
6
7:23
-:-
7
-:-
-:-
-:-
''';
    final days = ScrapeParsers.attendance(text, 2026, 10);
    expect(days.length, 7);
    expect(days[0].holiday, isTrue);
    expect(days[3].day, DateTime(2026, 10, 4));
    expect(days[3].checkIn, '7:25');
    expect(days[3].checkOut, isNull);
    expect(days[4].checkOut, '14:30');
    expect(days[6].checkIn, isNull);
  });

  test('النقاط والمجموع', () {
    const text = 'نقاط الاسكان\nالمجموع\n32\nنقاط الموظف\nالشهادة\n6\nالدرجة\n6\nالخدمة\n20\nالزوجية\n0';
    final p = ScrapeParsers.points(text)!;
    expect(p.total, 32);
    expect(p.items['الخدمة'], 20);
    expect(p.items.length, 4);
  });

  test('المجموع مكتوب بالكشيدة لا يُعد بندًا', () {
    const text = 'المجمـوع :\n32\nالشهادة\n6\nالدرجة\n6\nالخدمة\n20\nالزوجية\n0';
    final p = ScrapeParsers.points(text)!;
    expect(p.total, 32);
    expect(p.items.length, 4);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:idc_app/app/format.dart';
import 'package:idc_app/data/models.dart';

void main() {
  group('SalarySlip.fromJson', () {
    test('يجمع صفوف الخادم حسب المجموعة', () {
      final slip = SalarySlip.fromJson([
        {'salary_group': 'المدفوعات', 'salary_keys': 'الراتب الاسمي', 'salary_value': '780,000'},
        {'salary_group': 'المدفوعات', 'salary_keys': 'مخصصات الشهادة', 'salary_value': '351000'},
        {'salary_group': 'الاستقطاعات', 'salary_keys': 'التقاعد', 'salary_value': '78000'},
        {'salary_group': 'المعلومات الاساسية', 'salary_keys': 'الدرجة', 'salary_value': '7'},
      ], year: 2026, month: 10);
      expect(slip.groups.length, 3);
      expect(slip.totalPayments, 1131000);
      expect(slip.totalDeductions, 78000);
      expect(slip.net, 1053000);
      expect(slip.byKind(SalaryGroupKind.info)!.items.single.value, '7');
    });

    test('يقبل المفاتيح والقيم كقوائم داخل كائن data', () {
      final slip = SalarySlip.fromJson({
        'status': true,
        'data': [
          {
            'salary_group': 'الاستقطاعات',
            'salary_keys': ['التقاعد', 'الضريبة'],
            'salary_value': ['١٠٠٠', '500'],
          },
        ],
      }, year: 2026, month: 1);
      expect(slip.totalDeductions, 1500);
    });

    test('يأخذ الصافي من الخادم إن وجد', () {
      final slip = SalarySlip.fromJson({
        'المدفوعات': {'الراتب': '1000'},
        'المجموع': {'صافي الراتب': '900'},
      }, year: 2026, month: 1);
      expect(slip.net, 900);
    });
  });

  test('User.fromJson يقرأ حقول تسجيل الدخول', () {
    final u = User.fromJson({
      'user_id': '749',
      'user_display_name': 'محمد علي',
      'user_national_id': '123',
      'token': 'abc',
    });
    expect(u.id, '749');
    expect(u.firstName, 'محمد');
    expect(u.initial, 'م');
    expect(User.fromJson(u.toJson()).token, 'abc');
  });

  test('Notice يستنتج نوع التبليغ من العنوان', () {
    expect(Notice.fromJson({'mainstream_title': 'توطين الرواتب في المصرف'}).kind, NoticeKind.bank);
    expect(Notice.fromJson({'mainstream_title': 'استبيان جديد'}).kind, NoticeKind.survey);
  });

  test('timeAgo بالعربية', () {
    final now = DateTime(2026, 10, 26, 12);
    expect(timeAgo(now.subtract(const Duration(minutes: 2)), now: now), 'منذ دقيقتين');
    expect(timeAgo(now.subtract(const Duration(hours: 5)), now: now), 'منذ 5 ساعات');
    expect(timeAgo(now.subtract(const Duration(days: 1)), now: now), 'أمس');
  });

  test('AttendanceDay.late بعد 7:30', () {
    expect(AttendanceDay(DateTime(2026), checkIn: '7:30').late, false);
    expect(AttendanceDay(DateTime(2026), checkIn: '7:51').late, true);
  });

  test('نص التبليغ بلا وسوم HTML وروابط الصور كاملة', () {
    expect(plainText('مرحبا<br>بكم&nbsp;<b>جميعا</b>'), 'مرحبا\nبكم جميعا');
    expect(absoluteUrl('uploads/a.jpg'), 'https://idc-iq.net/application/v2/api/uploads/a.jpg');
    expect(absoluteUrl('https://x.y/a.jpg'), 'https://x.y/a.jpg');
    expect(absoluteUrl(''), isNull);
  });

  test('أقسام الراتب تأتي أرقامًا وتُعرض بأسمائها', () {
    final slip = SalarySlip.fromJson({
      'data': [
        {'salary_group': '1', 'salary_keys': 'السنة', 'salary_value': '2026'},
        {'salary_group': '3', 'salary_keys': 'حافز', 'salary_value': '711724'},
        {'salary_group': '4', 'salary_keys': 'تقاعد', 'salary_value': '30800'},
        {'salary_group': '5', 'salary_keys': 'الراتب الصافي', 'salary_value': '1815000'},
      ]
    }, year: 2026, month: 10);
    expect(slip.groups.first.title, 'المعلومات الأساسية');
    expect(slip.groups.first.kind, SalaryGroupKind.info);
    expect(slip.totalPayments, 711724);
    expect(slip.totalDeductions, 30800);
    expect(slip.net, 1815000);
  });
}

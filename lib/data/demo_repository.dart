import 'dart:typed_data';

import 'models.dart';
import 'repository.dart';

/// بيانات تجريبية لعرض التطبيق بدون الاتصال بخادم الشركة.
/// الأسماء والمبالغ هنا وهمية.
class DemoRepository implements Repository {
  static const _delay = Duration(milliseconds: 600);
  final List<Inquiry> _inquiries = [
    Inquiry(
      id: '1',
      title: 'تحديث الشهادة',
      body: 'أرجو تحديث بيانات الشهادة في الملف الوظيفي بعد حصولي على الماجستير.',
      date: DateTime(2026, 10, 20, 9, 15),
      replies: [
        InquiryReply(text: 'تم تحديث بيانات الشهادة في الملف الوظيفي.', fromEmployee: false, date: DateTime(2026, 10, 25, 11, 40)),
      ],
    ),
  ];

  @override
  void attach(User? user) {}

  @override
  Future<User> login(String username, String password) async {
    await Future.delayed(_delay);
    return const User(
      id: '100245',
      nationalId: '0',
      displayName: 'محمد عبد الله الحسن',
      token: 'demo',
      jobTitle: 'معاون مهندس',
    );
  }

  @override
  Future<void> resetPassword({required String username, required String phone}) => Future.delayed(_delay);

  @override
  Future<Uint8List?> salaryImage(int year, int month) async => null;

  @override
  Future<SalarySlip> salary(int year, int month) async {
    await Future.delayed(_delay);
    final bonus = (month % 3) * 15000;
    return SalarySlip(year: year, month: month, groups: [
      SalaryGroup('المدفوعات', [
        const SalaryItem('الراتب الاسمي', '780000'),
        const SalaryItem('مخصصات الشهادة', '351000'),
        const SalaryItem('مخصصات الخدمة', '279000'),
        if (bonus > 0) SalaryItem('مخصصات أخرى', '$bonus'),
      ]),
      const SalaryGroup('الاستقطاعات', [
        SalaryItem('التقاعد', '78000'),
        SalaryItem('ضريبة الدخل', '52000'),
        SalaryItem('سلفة مصرفية', '35000'),
      ]),
      const SalaryGroup('المعلومات الأساسية', [
        SalaryItem('الرقم الوظيفي', '100245'),
        SalaryItem('العنوان الوظيفي', 'معاون مهندس'),
        SalaryItem('الشهادة', 'بكالوريوس'),
        SalaryItem('الدرجة', '7'),
        SalaryItem('المرحلة', '3'),
        SalaryItem('تاريخ المباشرة', '2014-01-25'),
        SalaryItem('تاريخ العلاوة', '2027-06-01'),
      ]),
    ]);
  }

  @override
  Future<List<Notice>> notices({int page = 1}) async {
    await Future.delayed(_delay);
    if (page > 1) return const [];
    final now = DateTime.now();
    return [
      Notice(
        id: '1',
        title: 'تم صرف راتب الشهر الحالي',
        description: 'يمكنك الآن الاطلاع على قصاصة الراتب وحفظها من تبويب الراتب.',
        date: now.subtract(const Duration(minutes: 10)),
        read: false,
        kind: NoticeKind.salary,
      ),
      Notice(
        id: '2',
        title: 'توطين الرواتب في مصرف الاستثمار العراقي',
        description: 'عقد توطين رواتب منتسبي شركة الحفر العراقية لدى مصرف الاستثمار العراقي. يمكن الاطلاع على نص العقد كاملًا من المرفق.',
        date: now.subtract(const Duration(minutes: 30)),
        read: false,
        kind: NoticeKind.bank,
      ),
      Notice(
        id: '3',
        title: 'استبيان جديد',
        description: 'شاركنا رأيك في خدمات النقل للموظفين.',
        date: now.subtract(const Duration(hours: 1)),
        read: false,
        kind: NoticeKind.survey,
      ),
      Notice(
        id: '4',
        title: 'انطلاق دورة السلامة المهنية HSE',
        description: 'تبدأ الدورة الأسبوع القادم في قاعة التدريب. يرجى مراجعة قسم التدريب للتسجيل.',
        date: now.subtract(const Duration(days: 2)),
        kind: NoticeKind.training,
      ),
    ];
  }

  @override
  Future<int> unreadCount() async => 3;

  @override
  Future<List<Inquiry>> inquiries({int page = 1}) async {
    await Future.delayed(_delay);
    return page > 1 ? const [] : List.of(_inquiries);
  }

  @override
  Future<void> sendReply(String inquiryId, String text) async {
    await Future.delayed(_delay);
    final i = _inquiries.indexWhere((e) => e.id == inquiryId);
    if (i < 0) return;
    final q = _inquiries[i];
    _inquiries[i] = Inquiry(
      id: q.id,
      title: q.title,
      body: q.body,
      date: q.date,
      replies: [...q.replies, InquiryReply(text: text, fromEmployee: true, date: DateTime.now())],
    );
  }

  @override
  Future<void> changePassword(String oldPassword, String newPassword) => Future.delayed(_delay);

  @override
  Future<String?> uploadProfileImage(String filePath) async {
    await Future.delayed(_delay);
    return null;
  }

  @override
  Uri servicesPage() => Uri.parse('https://idc-iq.net/');

  @override
  bool get hasNativeServices => true;

  @override
  Future<List<AttendanceDay>> attendance(int year, int month) async {
    await Future.delayed(_delay);
    final days = DateTime(year, month + 1, 0).day;
    final today = DateTime.now();
    final times = ['7:25', '7:23', '7:18', '7:01', '6:53', '7:08', '7:27', '7:24', '7:30', '7:51', '7:00', '7:12'];
    return List.generate(days, (i) {
      final d = DateTime(year, month, i + 1);
      final weekend = d.weekday == DateTime.friday || d.weekday == DateTime.saturday;
      if (weekend) return AttendanceDay(d, holiday: true);
      if (d.isAfter(today)) return AttendanceDay(d);
      final t = times[i % times.length];
      final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
      return AttendanceDay(d, checkIn: t, checkOut: isToday ? null : '14:${(i * 7) % 50 + 10}');
    });
  }

  @override
  Future<HousingPoints> housingPoints() async {
    await Future.delayed(_delay);
    return const HousingPoints({
      'الخدمة': 20,
      'الشهادة': 6,
      'الدرجة': 6,
      'الزوجية': 0,
      'الأطفال': 0,
      'العجز': 0,
      'الشهداء': 0,
      'السجناء السياسيون': 0,
    }, fileClosed: true);
  }

  @override
  Future<List<Course>> courses() async {
    await Future.delayed(_delay);
    return [
      Course('شبكة الواي فاي باستخدام المايكروتك', DateTime(2026, 7, 12), DateTime(2026, 7, 16)),
      Course('مكافحة الفساد في ضوء التشريعات', DateTime(2026, 2, 15), DateTime(2026, 2, 19)),
      Course('الإسعافات الأولية HSE', DateTime(2025, 12, 14), DateTime(2025, 12, 18)),
      Course('فن التعامل مع البريد الإلكتروني', DateTime(2025, 10, 5), DateTime(2025, 10, 9)),
    ];
  }

  @override
  Future<List<ThanksLetter>> thanksLetters() async {
    await Future.delayed(_delay);
    return [
      ThanksLetter('17533', DateTime(2026, 9, 17), '6 أشهر قدم، كتاب رئاسة الوزراء'),
      ThanksLetter('3184', DateTime(2026, 8, 16), ''),
      ThanksLetter('948', DateTime(2026, 3, 2), ''),
      ThanksLetter('373', DateTime(2026, 1, 29), ''),
    ];
  }

  @override
  Future<ServicePage> servicePage(String service) async {
    await Future.delayed(_delay);
    return const ServicePage(['تُعرض هنا بيانات الخدمة من خادم الشركة بعد تسجيل الدخول برقمك الوظيفي.'], []);
  }
}

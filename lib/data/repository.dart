import 'dart:typed_data';

import 'models.dart';

/// واجهة موحدة لمصدر البيانات. لها تنفيذان: خادم الشركة (ApiRepository)
/// ونسخة تجريبية ببيانات وهمية (DemoRepository) لعرض التطبيق بدون حساب.
abstract class Repository {
  void attach(User? user);

  Future<User> login(String username, String password);
  Future<void> resetPassword({required String username, required String phone});

  Future<SalarySlip> salary(int year, int month);

  /// صورة القصاصة الرسمية كما يصدرها خادم الشركة، أو null إن لم تتوفر.
  Future<Uint8List?> salaryImage(int year, int month);

  Future<List<Notice>> notices({int page = 1});
  Future<int> unreadCount();

  Future<List<Inquiry>> inquiries({int page = 1});
  Future<void> sendReply(String inquiryId, String text);

  Future<void> changePassword(String oldPassword, String newPassword);
  Future<String?> uploadProfileImage(String filePath);

  /// صفحة خدمات الموظف على خادم الشركة.
  Uri servicesPage();

  /// هل تتوفر بيانات الخدمات بصيغة يمكن عرضها بتصميم التطبيق مباشرة؟
  bool get hasNativeServices;

  Future<List<AttendanceDay>> attendance(int year, int month);
  Future<HousingPoints> housingPoints();
  Future<List<Course>> courses();
  Future<List<ThanksLetter>> thanksLetters();

  /// محتوى خدمة لا تحتاج تصميمًا خاصًا (الأرباح، قطع الأراضي، الاستبيان، الزمنيات).
  Future<ServicePage> servicePage(String service);
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../services/web_scraper.dart';
import 'models.dart';
import 'scrape_parsers.dart';
import 'repository.dart';

/// عناوين خادم الشركة كما وردت في التطبيق الأصلي (الإصدار 2.0.3).
/// أسماء المعاملات المرسلة مستنتجة من الكود المترجم، وكلها مجمعة هنا
/// لتسهيل تعديلها إن اختلف شكل الطلب.
class Endpoints {
  static const base = 'https://idc-iq.net/application/v2/api/';
  static const login = 'login.php?action=login';
  static const resetPassword = 'reset_password.php';
  static const salaries = 'salaries.php';
  static const salaryImage = 'salary_image.php';
  static const notices = 'mainstreamPag.php';
  static const inquiries = 'inquires_pag.php';
  static const addReply = 'inquires1.php';
  static const user = 'user.php';
  static const uploadPic = 'upload_profile_pic.php';
  static const servicesPage = 'egate/home_page.php';
  static const webPage = 'app_web_page.php';
}

class ApiException implements Exception {
  final String message;

  /// تفاصيل تقنية تُعرض عند الطلب للمساعدة في معرفة سبب الخطأ.
  final String? details;
  const ApiException(this.message, [this.details]);
  @override
  String toString() => message;
}

class ApiRepository implements Repository {
  final Dio _dio;
  User? _user;

  ApiRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Endpoints.base,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              responseType: ResponseType.plain,
            ),
          );

  @override
  void attach(User? user) => _user = user;

  String get _token {
    final t = _user?.token;
    if (t == null || t.isEmpty) throw const ApiException('انتهت الجلسة، سجّل الدخول مرة أخرى');
    return t;
  }

  Future<Object?> _send(Future<Response<String>> Function() call) async {
    try {
      final res = await call();
      final body = res.data ?? '';
      if (body.trim().isEmpty) return null;
      final decoded = jsonDecode(body);
      _throwIfError(decoded);
      return decoded;
    } on DioException catch (e) {
      throw ApiException(_dioMessage(e));
    } on FormatException {
      throw const ApiException('رد غير متوقع من الخادم، حاول مرة أخرى لاحقًا');
    } on SocketException {
      throw const ApiException('تعذر الوصول للخادم، تأكد من الاتصال بالإنترنت');
    }
  }

  void _throwIfError(Object? json) {
    if (json is! Map) return;
    // الخادم يرد بـ 401 أيضًا على الطلبات غير المسموحة، فتظهر رسالته كما هي.
    if ('${json['http_response_code']}' == '401') {
      throw ApiException('رفض الخادم الطلب: ${json['data'] ?? ''}'.trim());
    }
    final status = '${json['status'] ?? json['success'] ?? json['result'] ?? ''}'.toLowerCase();
    if (status == 'false' || status == 'error' || status == 'fail' || status == '0') {
      final msg = str(json, ['message', 'msg', 'error', 'errorText', 'error_text'], 'حدث خطأ ما، حاول مرة أخرى');
      throw ApiException(msg);
    }
  }

  String _dioMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'انقطع الاتصال قبل انتهاء تحميل البيانات';
      case DioExceptionType.connectionError:
        return 'تعذر الوصول للخادم، تأكد من الاتصال بالإنترنت';
      default:
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) return 'انتهت الجلسة، سجّل الدخول مرة أخرى';
        return 'حدث خلل ما، حاول مرة أخرى لاحقًا';
    }
  }

  Object? _unwrap(Object? json) => json is Map && json['data'] != null ? json['data'] : json;

  /// صيغة الدخول كما في التطبيق الأصلي: طلب POST بجسم JSON فيه الحقول
  /// email (الرقم الوظيفي) و password و fcmToken و platform، والرد يحمل
  /// http_response_code و token و userData.
  @override
  Future<User> login(String username, String password) async {
    final Response<String> res;
    try {
      res = await _dio.post<String>(
        Endpoints.login,
        data: jsonEncode({'email': username, 'password': password, 'fcmToken': '', 'platform': 'android'}),
        options: Options(contentType: 'text/plain; charset=utf-8'),
      );
    } on DioException catch (e) {
      throw ApiException(_dioMessage(e), _short(e.response?.data?.toString() ?? e.message ?? ''));
    }
    final body = res.data ?? '';
    Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      throw ApiException('رد غير متوقع من الخادم، حاول مرة أخرى لاحقًا', 'HTTP ${res.statusCode}: ${_short(body)}');
    }
    final code = json is Map ? '${json['http_response_code']}' : '';
    if (json is Map && code == '200' && json['userData'] is Map) {
      _user = User.fromJson({...json['userData'] as Map, 'token': json['token'] ?? ''});
      return _user!;
    }
    if (code == '404') throw const ApiException('اسم المستخدم أو كلمة المرور غير صحيحة');
    throw ApiException('لم يتعرف التطبيق على رد الخادم', 'HTTP ${res.statusCode}: ${_short(body)}');
  }

  static String _short(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // إخفاء أي رمز دخول قد يظهر في الرد قبل عرضه.
    final masked = t.replaceAllMapped(RegExp(r'("token"\s*:\s*")([^"]{4})[^"]*'), (m) => '${m[1]}${m[2]}…');
    return masked.length > 160 ? '${masked.substring(0, 160)}…' : masked;
  }

  @override
  Future<void> resetPassword({required String username, required String phone}) async {
    await _send(
      () => _dio.post<String>(Endpoints.resetPassword, data: FormData.fromMap({'username': username, 'phone': phone})),
    );
  }

  String get _userId => _user?.id ?? '';

  @override
  Future<SalarySlip> salary(int year, int month) async {
    final json = await _send(
      () => _dio.get<String>(
        Endpoints.salaries,
        queryParameters: {
          'token': _token,
          'userNationalId': _user?.nationalId ?? '',
          'salaryMonth': month,
          'salaryYear': year,
          'userId': _userId,
        },
      ),
    );
    return SalarySlip.fromJson(json, year: year, month: month);
  }

  /// القصاصة الرسمية كما في التطبيق الأصلي: تُفتح صفحة salary_image.php
  /// فتولّد صورة النموذج على الخادم وترسل رابطها عبر قناة ReceiveMessage،
  /// ثم تُنزَّل الصورة ويُطلب من الخادم حذف نسختها المؤقتة. يُبنى العنوان
  /// حرفيًا كالتطبيق الأصلي، والرمز دون ترميز إضافي.
  @override
  Uri salaryImagePage(int year, int month) => Uri.parse(
    '${Endpoints.base}${Endpoints.salaryImage}?eid=$_userId&&salaryMonth=$month'
    '&&salaryYear=$year&&token=$_token',
  );

  @override
  Future<Uint8List?> downloadSalaryImage(String message, int year, int month) async {
    final msg = message.trim().replaceAll('"', '');
    if (msg.isEmpty) return null;
    try {
      if (msg.startsWith('data:')) return UriData.parse(msg).contentAsBytes();
      final imageUrl = Uri.parse(Endpoints.base).resolve(msg);
      final res = await _dio.getUri<List<int>>(imageUrl, options: Options(responseType: ResponseType.bytes));
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } on DioException {
      return null;
    } on FormatException {
      return null;
    } finally {
      _dio.get<String>('delete_salary_image.php?action=deleteSalaryImage&imageName=$_userId$month$year').ignore();
    }
  }

  static const _noticesPerPage = 10;

  @override
  Future<List<Notice>> notices({int page = 1}) async {
    // يُبنى العنوان بنفس ترتيب التطبيق الأصلي حرفيًا، بما في ذلك وضع حجم
    // الصفحة بعد رقم المستخدم، لأن الخادم مضبوط على هذه الصيغة.
    final next = (page - 1) * _noticesPerPage;
    final url =
        '${Endpoints.notices}?action=readAll&token=${Uri.encodeQueryComponent(_token)}'
        '&maxPag=&userId=$_userId$_noticesPerPage&next=$next';
    final json = await _send(() => _dio.get<String>(url));
    final data = _unwrap(json);
    return data is List ? data.whereType<Map>().map(Notice.fromJson).toList() : const [];
  }

  // لا يوفر الخادم عددًا للتبليغات غير المقروءة؛ checkForMessage في التطبيق
  // الأصلي يعيد رسائل التنبيه والتحديث فقط.
  @override
  Future<int> unreadCount() async => 0;

  // الاستفسارات في التطبيق الأصلي تفتح من الإشعارات فقط، ولا توجد قائمة لها
  // على الخادم.
  @override
  Future<List<Inquiry>> inquiries({int page = 1}) async => const [];

  @override
  Future<void> sendReply(String inquiryId, String text) async {
    await _send(
      () => _dio.post<String>(
        Endpoints.addReply,
        queryParameters: {'action': 'addReply', 'token': _token},
        data: jsonEncode({
          'inquiryId': inquiryId,
          'text': text,
          'replayType': '2',
          'replyDate': DateTime.now().toString(),
        }),
        options: Options(contentType: 'text/plain; charset=utf-8'),
      ),
    );
  }

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final json = await _send(
      () => _dio.post<String>(
        Endpoints.user,
        queryParameters: {'action': 'changePassword', 'token': _token},
        data: jsonEncode({'userId': _userId, 'oldPassword': oldPassword, 'newPassword': newPassword}),
        options: Options(contentType: 'text/plain; charset=utf-8'),
      ),
    );
    if (json is Map && '${json['http_response_code']}' != '200') {
      throw const ApiException('كلمة المرور الحالية غير صحيحة');
    }
  }

  @override
  Future<String?> uploadProfileImage(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final json = await _send(
      () => _dio.post<String>(
        Endpoints.uploadPic,
        queryParameters: {'action': 'uploadProfilePic', 'token': _token, 'userId': _userId},
        data: {'image': base64Encode(bytes)},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
    );
    if (json is Map && '${json['http_response_code']}' != '200') {
      throw const ApiException('تعذر رفع الصورة، حاول مرة أخرى');
    }
    final data = _unwrap(json);
    if (data is String && data.startsWith('http')) return data;
    return data is Map ? pick(data, ['user_image_url', 'image_url', 'url', 'profileImage'])?.toString() : null;
  }

  @override
  Uri servicesPage() =>
      Uri.parse('${Endpoints.base}${Endpoints.servicesPage}')
          .replace(queryParameters: {'eid': _userId, 'token': _user?.token ?? ''});

  // الخدمات لا تتوفر إلا كصفحات ويب داخل قائمة الخدمات، فتُقرأ بياناتها
  // بمتصفح مخفي (WebScraper) وتعرض بتصميم التطبيق.
  @override
  bool get hasNativeServices => true;

  Future<Map> _scrape(String service, {List<String> more = const []}) async {
    final Object? out;
    try {
      out = await WebScraper.instance.service(servicesPage(), service, more: more, extract: ScrapeScripts.extract);
    } catch (_) {
      throw const ApiException('تعذر الوصول للخادم، تأكد من الاتصال بالإنترنت');
    }
    if (out is! Map) throw const ApiException('تعذر قراءة بيانات الخدمة من الخادم');
    return out;
  }

  /// صفوف أول جدول يطابق عنوانه [match]. إن لم يوجد جدول كهذا فالصفحة لم
  /// تُقرأ كما يجب، فيظهر خطأ مع مقتطف منها بدل قائمة فارغة مضللة.
  static List<List<String>> _table(Map page, bool Function(String header) match) {
    final tables = page['tables'];
    if (tables is! List) throw ApiException('تعذر قراءة بيانات الخدمة من الخادم', _pageDetails(page));
    for (final t in tables) {
      if (t is! List || t.isEmpty) continue;
      final rows = t.map((r) => r is List ? r.map((c) => '$c').toList() : <String>[]).toList();
      if (match(rows.first.join(' '))) return rows.skip(1).where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
    }
    // صفحة بلا جدول قد تعني عدم وجود بيانات، كما في «لا توجد دورات».
    if (tables.isEmpty) return const [];
    throw ApiException('تعذر قراءة بيانات الخدمة من الخادم', _pageDetails(page));
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Future<List<Course>> courses() => _cached('courses', () async {
    final page = await _scrape('الدورات');
    return [
      for (final r in _table(page, (h) => h.contains('الدورة')))
        if (r.isNotEmpty)
          Course(
            _clean(r[0]),
            r.length > 1 ? parseDate(_clean(r[1])) : null,
            r.length > 2 ? parseDate(_clean(r[2])) : null,
          ),
    ];
  });

  @override
  Future<List<ThanksLetter>> thanksLetters() => _cached('thanks', () async {
    final page = await _scrape('التشكرات');
    return [
      for (final r in _table(page, (h) => h.contains('الكتاب')))
        if (r.isNotEmpty)
          ThanksLetter(_clean(r[0]), r.length > 1 ? parseDate(_clean(r[1])) : null, r.length > 2 ? _clean(r[2]) : ''),
    ];
  });

  @override
  Future<HousingPoints> housingPoints() => _cached('points', () async {
    final page = await _scrape('نقاطي');
    return ScrapeParsers.points('${page['text'] ?? ''}') ??
        (throw ApiException('تعذر قراءة بيانات النقاط من الخادم', _pageDetails(page)));
  });

  @override
  Future<List<AttendanceDay>> attendance(int year, int month) => _cached('attendance-$year-$month', () async {
    // التقويم يُرسم بعد فتح الصفحة، فيُنتظر ظهوره قبل اختيار الشهر وبعده.
    final steps = [
      ScrapeScripts.waitForCalendar(16),
      ScrapeScripts.attendanceMonth(year, month),
      ScrapeScripts.waitForCalendar(50),
    ];
    var page = await _scrape('الحضور', more: steps);
    var days = ScrapeParsers.attendance('${page['text'] ?? ''}', year, month);
    // محاولة ثانية تلقائية إن لم يكتمل تحميل التقويم في الأولى.
    if (days.isEmpty) {
      page = await _scrape('الحضور', more: steps);
      days = ScrapeParsers.attendance('${page['text'] ?? ''}', year, month);
    }
    if (days.isEmpty) throw ApiException('لا توجد بيانات حضور لهذا الشهر', _pageDetails(page));
    return days;
  });

  /// نتائج صفحات الخدمات تُحفظ دقائق قليلة، لأن قراءتها أبطأ من طلبات
  /// الخادم العادية وتطلبها الرئيسية وشاشات الخدمات معًا.
  final _cache = <String, (DateTime, Future<Object?>)>{};
  Future<T> _cached<T>(String key, Future<T> Function() load) {
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.$1) < const Duration(minutes: 5)) {
      return hit.$2.then((v) => v as T);
    }
    final f = load();
    _cache[key] = (DateTime.now(), f);
    // الفشل لا يُحفظ حتى تعيد المحاولة التالية الطلب من جديد.
    f.then(
      (_) {},
      onError: (_) {
        _cache.remove(key);
      },
    );
    return f;
  }

  /// مقتطف من الصفحة يظهر في «التفاصيل» حين يتعذر تفسيرها.
  static String _pageDetails(Map page) {
    final t = '${page['text'] ?? ''}'.replaceAll(RegExp(r'\n+'), ' | ');
    return t.length > 1500 ? t.substring(0, 1500) : t;
  }

  @override
  Future<ServicePage> servicePage(String service) async {
    final page = await _scrape(service);
    // يُحذف عنوان الصفحة المكرر لأن شاشة التطبيق تعرضه في شريطها.
    String norm(String s) => s.replaceAll(RegExp('[أإآ]'), 'ا').replaceFirst(RegExp('^ال'), '').trim();
    final title = norm(service);
    final lines = '${page['text'] ?? ''}'
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && norm(l) != title)
        .toList();
    final images = page['images'] is List ? (page['images'] as List).map((e) => '$e').toList() : <String>[];
    return ServicePage(lines, images);
  }
}

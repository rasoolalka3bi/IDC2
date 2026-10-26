import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'models.dart';
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
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Endpoints.base,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              responseType: ResponseType.plain,
            ));

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

  /// يبحث داخل الرد عن كائن فيه بيانات المستخدم مهما كان مستوى تداخله.
  static Map? _findUser(Object? json, [int depth = 0]) {
    if (depth > 4 || json == null) return null;
    if (json is Map) {
      if (pick(json, ['user_id', 'userId', 'token', 'user_display_name', 'eid']) != null) return json;
      for (final v in json.values) {
        final f = _findUser(v, depth + 1);
        if (f != null) return f;
      }
    } else if (json is List) {
      for (final v in json) {
        final f = _findUser(v, depth + 1);
        if (f != null) return f;
      }
    } else if (json is String && json.trim().startsWith(RegExp(r'[\[{]'))) {
      try {
        return _findUser(jsonDecode(json), depth + 1);
      } catch (_) {}
    }
    return null;
  }

  static bool _denied(Object? json) {
    if (json is! Map) return false;
    final a = '${json['authorized'] ?? json['status'] ?? json['success'] ?? ''}'.toLowerCase();
    return a == 'false' || a == '0' || a == 'error' || a == 'fail';
  }

  /// صيغة الطلب التي يقبلها خادم الشركة غير موثقة، لذلك تُجرَّب الصيغ الشائعة
  /// بالترتيب ويُحفظ ما نجح منها. عند الفشل تُجمع الردود لعرضها كتفاصيل.
  @override
  Future<User> login(String username, String password) async {
    // التطبيق القديم يحتوي على المفاتيح username و pass و fcmToken و deviceId،
    // وقد تكون كلمة المرور مشفرة بـ md5، فتُجرَّب هذه الاحتمالات بالترتيب.
    final hashed = md5.convert(utf8.encode(password)).toString();
    final variants = <String, Map<String, String>>{
      'pass': {'username': username, 'pass': password, 'fcmToken': '', 'deviceId': ''},
      'password': {'username': username, 'password': password},
      'pass+md5': {'username': username, 'pass': hashed, 'fcmToken': '', 'deviceId': ''},
      'password+md5': {'username': username, 'password': hashed},
    };
    final attempts = <String, Future<Response<String>> Function()>{};
    for (final v in variants.entries) {
      final f = v.value;
      attempts['${v.key}/form'] = () => _dio.post<String>(Endpoints.login,
          data: f, options: Options(contentType: Headers.formUrlEncodedContentType));
      attempts['${v.key}/multipart'] = () => _dio.post<String>(Endpoints.login, data: FormData.fromMap(f));
      attempts['${v.key}/json'] = () =>
          _dio.post<String>(Endpoints.login, data: jsonEncode(f), options: Options(contentType: Headers.jsonContentType));
    }
    final log = StringBuffer();
    var denied = false;
    var reached = false;
    for (final e in attempts.entries) {
      try {
        final res = await e.value();
        reached = true;
        final body = res.data ?? '';
        log.writeln('[${e.key}] HTTP ${res.statusCode}: ${_short(body)}');
        Object? json;
        try {
          json = body.trim().isEmpty ? null : jsonDecode(body);
        } catch (_) {
          json = null;
        }
        final m = _findUser(json);
        if (m != null) {
          final user = User.fromJson(m);
          if (user.token.isNotEmpty || user.id.isNotEmpty) {
            _user = user.token.isEmpty ? User.fromJson({...m, 'token': str(json is Map ? json : {}, ['token'])}) : user;
            return _user!;
          }
        }
        if (_denied(json)) denied = true;
      } on DioException catch (err) {
        if (err.response != null) reached = true;
        log.writeln('[${e.key}] ${err.type.name} ${err.response?.statusCode ?? ''}: ${_short(err.response?.data?.toString() ?? err.message ?? '')}');
      }
    }
    if (!reached) throw ApiException('تعذر الوصول للخادم، تأكد من الاتصال بالإنترنت', log.toString());
    throw ApiException(
      denied ? 'اسم المستخدم أو كلمة المرور غير صحيحة' : 'لم يتعرف التطبيق على رد الخادم',
      log.toString(),
    );
  }

  static String _short(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // إخفاء أي رمز دخول قد يظهر في الرد قبل عرضه.
    final masked = t.replaceAllMapped(RegExp(r'("token"\s*:\s*")([^"]{4})[^"]*'), (m) => '${m[1]}${m[2]}…');
    return masked.length > 160 ? '${masked.substring(0, 160)}…' : masked;
  }

  @override
  Future<void> resetPassword({required String username, required String phone}) async {
    await _send(() => _dio.post<String>(
          Endpoints.resetPassword,
          data: FormData.fromMap({'username': username, 'phone': phone}),
        ));
  }

  @override
  Future<SalarySlip> salary(int year, int month) async {
    final json = await _send(() => _dio.get<String>(
          Endpoints.salaries,
          queryParameters: {'token': _token, 'salaryYear': year, 'salaryMonth': month},
        ));
    return SalarySlip.fromJson(json, year: year, month: month);
  }

  @override
  Future<List<Notice>> notices({int page = 1}) async {
    final json = await _send(() => _dio.get<String>(
          Endpoints.notices,
          queryParameters: {'action': 'readAll', 'token': _token, 'page': page},
        ));
    final data = _unwrap(json);
    return data is List ? data.whereType<Map>().map(Notice.fromJson).toList() : const [];
  }

  @override
  Future<int> unreadCount() async {
    final json = await _send(() => _dio.get<String>(
          Endpoints.notices,
          queryParameters: {'action': 'checkForMessage', 'userId': _user?.id ?? ''},
        ));
    final data = _unwrap(json);
    if (data is num) return data.toInt();
    if (data is Map) return int.tryParse('${pick(data, ['count', 'unread', 'messages']) ?? 0}') ?? 0;
    if (data is List) return data.length;
    return int.tryParse('$data') ?? 0;
  }

  @override
  Future<List<Inquiry>> inquiries({int page = 1}) async {
    final json = await _send(() => _dio.get<String>(
          Endpoints.inquiries,
          queryParameters: {'action': 'inquiriesRepliesPag', 'token': _token, 'page': page},
        ));
    final data = _unwrap(json);
    return data is List ? data.whereType<Map>().map(Inquiry.fromJson).toList() : const [];
  }

  @override
  Future<void> sendReply(String inquiryId, String text) async {
    await _send(() => _dio.post<String>(
          Endpoints.addReply,
          queryParameters: {'action': 'addReply', 'token': _token},
          data: FormData.fromMap({'inquiryId': inquiryId, 'reply_text': text}),
        ));
  }

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _send(() => _dio.post<String>(
          Endpoints.user,
          queryParameters: {'action': 'changePassword', 'token': _token},
          data: FormData.fromMap({'oldPassword': oldPassword, 'newPassword': newPassword}),
        ));
  }

  @override
  Future<String?> uploadProfileImage(String filePath) async {
    final json = await _send(() async => _dio.post<String>(
          Endpoints.uploadPic,
          queryParameters: {'action': 'uploadProfilePic', 'token': _token},
          data: FormData.fromMap({'image': await MultipartFile.fromFile(filePath, filename: 'profile.jpg')}),
        ));
    final data = _unwrap(json);
    return data is Map ? pick(data, ['user_image_url', 'image_url', 'url'])?.toString() : null;
  }

  @override
  Uri servicesPage() => Uri.parse('${Endpoints.base}${Endpoints.servicesPage}').replace(queryParameters: {
        'eid': _user?.id ?? '',
        'userNationalId': _user?.nationalId ?? '',
      });

  // خدمات الحضور والنقاط والدورات والتشكرات تعرض حاليًا كصفحات ويب من الخادم
  // ولا توجد لها واجهة JSON معروفة، لذلك تفتح من خلال servicesPage() إلى أن
  // توفر الشركة واجهة بيانات لها.
  @override
  bool get hasNativeServices => false;

  @override
  Future<List<AttendanceDay>> attendance(int year, int month) => throw const ApiException('غير متاح');
  @override
  Future<HousingPoints> housingPoints() => throw const ApiException('غير متاح');
  @override
  Future<List<Course>> courses() => throw const ApiException('غير متاح');
  @override
  Future<List<ThanksLetter>> thanksLetters() => throw const ApiException('غير متاح');
}

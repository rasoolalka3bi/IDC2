import 'dart:convert';
import 'dart:io';

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
  const ApiException(this.message);
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

  @override
  Future<User> login(String username, String password) async {
    final json = await _send(() => _dio.post<String>(
          Endpoints.login,
          data: FormData.fromMap({'username': username, 'password': password}),
        ));
    final data = _unwrap(json);
    if (data is! Map) throw const ApiException('اسم المستخدم أو كلمة المرور غير صحيحة');
    final user = User.fromJson(data);
    if (user.token.isEmpty && user.id.isEmpty) {
      throw const ApiException('اسم المستخدم أو كلمة المرور غير صحيحة');
    }
    _user = user;
    return user;
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

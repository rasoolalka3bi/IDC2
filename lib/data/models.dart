/// نماذج البيانات. أسماء الحقول مأخوذة من التطبيق الأصلي (الإصدار 2.0.3)،
/// والقراءة متسامحة: تقبل أكثر من اسم للحقل نفسه لأن شكل ردود الخادم غير موثق.
library;

dynamic pick(Map m, List<String> keys) {
  for (final k in keys) {
    if (m.containsKey(k) && m[k] != null && '${m[k]}'.isNotEmpty) return m[k];
  }
  return null;
}

String str(Map m, List<String> keys, [String fallback = '']) => pick(m, keys)?.toString().trim() ?? fallback;

DateTime? parseDate(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final n = int.tryParse(s);
  if (n != null) return DateTime.fromMillisecondsSinceEpoch(n > 9999999999 ? n : n * 1000);
  return DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

class User {
  final String id;
  final String nationalId;
  final String displayName;
  final String? imageUrl;
  final String token;
  final String? jobTitle;

  const User({
    required this.id,
    required this.nationalId,
    required this.displayName,
    required this.token,
    this.imageUrl,
    this.jobTitle,
  });

  String get firstName => displayName.split(' ').first;
  String get initial => displayName.isEmpty ? '؟' : displayName.characters.first;

  factory User.fromJson(Map m) => User(
        id: str(m, ['user_id', 'userId', 'id', 'eid']),
        nationalId: str(m, ['user_national_id', 'userNationalId', 'national_id']),
        displayName: str(m, ['user_display_name', 'userDisplayName', 'display_name', 'name']),
        imageUrl: pick(m, ['user_image_url', 'userImageUrl', 'image_url', 'profileImage'])?.toString(),
        token: str(m, ['token', 'access_token', 'user_token']),
        jobTitle: pick(m, ['job_title', 'jobTitle'])?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'user_id': id,
        'user_national_id': nationalId,
        'user_display_name': displayName,
        'user_image_url': imageUrl,
        'token': token,
        'job_title': jobTitle,
      };

  User copyWith({String? imageUrl, String? jobTitle}) => User(
        id: id,
        nationalId: nationalId,
        displayName: displayName,
        token: token,
        imageUrl: imageUrl ?? this.imageUrl,
        jobTitle: jobTitle ?? this.jobTitle,
      );
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}

/// بند واحد في قصاصة الراتب (اسم وقيمة).
class SalaryItem {
  final String label;
  final String value;
  const SalaryItem(this.label, this.value);

  /// القيمة كرقم إن أمكن (تُزال الفواصل والرموز).
  double? get amount {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.\-٠-٩]'), '');
    return double.tryParse(_toLatinDigits(cleaned));
  }
}

String _toLatinDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

enum SalaryGroupKind { info, payments, deductions, totals, other }

class SalaryGroup {
  final String title;
  final List<SalaryItem> items;
  const SalaryGroup(this.title, this.items);

  SalaryGroupKind get kind {
    final t = title;
    if (t.contains('معلومات')) return SalaryGroupKind.info;
    if (t.contains('مدفوع') || t.contains('استحقاق') || t.contains('مخصص')) return SalaryGroupKind.payments;
    if (t.contains('استقطاع')) return SalaryGroupKind.deductions;
    if (t.contains('مجموع') || t.contains('صافي') || t.contains('اجمال') || t.contains('إجمال')) return SalaryGroupKind.totals;
    return SalaryGroupKind.other;
  }

  double get sum => items.fold(0, (a, b) => a + (b.amount ?? 0));
}

class SalarySlip {
  final int year;
  final int month;
  final List<SalaryGroup> groups;
  const SalarySlip({required this.year, required this.month, required this.groups});

  bool get isEmpty => groups.every((g) => g.items.isEmpty);

  SalaryGroup? byKind(SalaryGroupKind k) {
    for (final g in groups) {
      if (g.kind == k) return g;
    }
    return null;
  }

  double get totalPayments => byKind(SalaryGroupKind.payments)?.sum ?? 0;
  double get totalDeductions => byKind(SalaryGroupKind.deductions)?.sum ?? 0;

  /// صافي الراتب: يُؤخذ من الخادم إن وُجد بند صافٍ، وإلا يُحسب.
  double get net {
    for (final g in groups) {
      for (final i in g.items) {
        if (i.label.contains('صافي') && i.amount != null) return i.amount!;
      }
    }
    return totalPayments - totalDeductions;
  }

  /// يقبل الشكلين المحتملين: قائمة صفوف {salary_group, salary_keys, salary_value}
  /// أو خريطة {اسم المجموعة: {اسم البند: القيمة}}.
  factory SalarySlip.fromJson(Object? json, {required int year, required int month}) {
    final groups = <String, List<SalaryItem>>{};
    void add(String g, String k, String v) => (groups[g] ??= []).add(SalaryItem(k, v));

    Object? data = json;
    if (data is Map && data['data'] != null) data = data['data'];

    if (data is List) {
      for (final row in data.whereType<Map>()) {
        final g = str(row, ['salary_group', 'group', 'salaryGroup'], 'تفاصيل');
        final keys = pick(row, ['salary_keys', 'salary_key', 'key', 'label']);
        final vals = pick(row, ['salary_value', 'salary_values', 'value']);
        if (keys is List && vals is List) {
          for (var i = 0; i < keys.length && i < vals.length; i++) {
            add(g, '${keys[i]}', '${vals[i]}');
          }
        } else if (keys is Map) {
          keys.forEach((k, v) => add(g, '$k', '$v'));
        } else if (keys != null) {
          add(g, '$keys', '${vals ?? ''}');
        }
      }
    } else if (data is Map) {
      data.forEach((g, v) {
        if (v is Map) {
          v.forEach((k, val) => add('$g', '$k', '$val'));
        } else if (v is List) {
          for (final r in v.whereType<Map>()) {
            add('$g', str(r, ['salary_keys', 'key', 'label']), str(r, ['salary_value', 'value']));
          }
        }
      });
    }
    return SalarySlip(
      year: year,
      month: month,
      groups: groups.entries.map((e) => SalaryGroup(e.key, e.value)).toList(),
    );
  }
}

/// تبليغ أو خبر من الشركة (mainstream في الخادم).
class Notice {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime? date;
  final bool read;
  final NoticeKind kind;

  const Notice({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.date,
    this.read = true,
    this.kind = NoticeKind.general,
  });

  factory Notice.fromJson(Map m) {
    final title = str(m, ['mainstream_title', 'title']);
    return Notice(
      id: str(m, ['mainstream_id', 'id', 'newsid']),
      title: title,
      description: str(m, ['mainstream_description', 'description', 'body', 'content']),
      imageUrl: pick(m, ['mainstream_image_url', 'image_url', 'imageUrl'])?.toString(),
      date: parseDate(pick(m, ['mainstream_date', 'date', 'created_at', 'created'])),
      read: '${pick(m, ['read', 'is_read', 'seen']) ?? '1'}' != '0',
      kind: NoticeKind.guess(title),
    );
  }
}

enum NoticeKind {
  salary,
  survey,
  bank,
  training,
  general;

  static NoticeKind guess(String title) {
    if (title.contains('راتب') || title.contains('رواتب')) return title.contains('مصرف') ? bank : salary;
    if (title.contains('استبيان')) return survey;
    if (title.contains('مصرف') || title.contains('توطين')) return bank;
    if (title.contains('دورة') || title.contains('دورات')) return training;
    return general;
  }
}

class InquiryReply {
  final String text;
  final bool fromEmployee;
  final DateTime? date;
  const InquiryReply({required this.text, required this.fromEmployee, this.date});

  factory InquiryReply.fromJson(Map m) {
    final type = str(m, ['reply_type', 'replyType', 'type']).toLowerCase();
    return InquiryReply(
      text: str(m, ['reply_text', 'replyText', 'text']),
      // التطبيق الأصلي يرسل ردود الموظف بالنوع 2.
      fromEmployee: type == '2' || type == 'user' || type == 'employee' || type == 'emp',
      date: parseDate(pick(m, ['reply_date', 'replyDate', 'date'])),
    );
  }
}

class Inquiry {
  final String id;
  final String title;
  final String body;
  final DateTime? date;
  final List<InquiryReply> replies;

  const Inquiry({required this.id, required this.title, required this.body, this.date, this.replies = const []});

  bool get answered => replies.any((r) => !r.fromEmployee);

  factory Inquiry.fromJson(Map m) {
    final rs = pick(m, ['replies', 'inquiriesReplies', 'reply']);
    return Inquiry(
      id: str(m, ['inquireid', 'inquiryId', 'inquiry_id', 'id']),
      title: str(m, ['inquire_title', 'title', 'subject'], 'استفسار'),
      body: str(m, ['inquire_text', 'inquiry_text', 'text', 'body', 'description']),
      date: parseDate(pick(m, ['inquire_date', 'date', 'created_at'])),
      replies: rs is List ? rs.whereType<Map>().map(InquiryReply.fromJson).toList() : const [],
    );
  }
}

/// نماذج الخدمات (الحضور، النقاط، الدورات، كتب الشكر).
class AttendanceDay {
  final DateTime day;
  final String? checkIn;
  final String? checkOut;
  final bool holiday;
  const AttendanceDay(this.day, {this.checkIn, this.checkOut, this.holiday = false});

  bool get late {
    if (checkIn == null) return false;
    final p = checkIn!.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return h * 60 + m > 7 * 60 + 30;
  }
}

class HousingPoints {
  final Map<String, int> items;
  final int max;
  final bool fileClosed;
  const HousingPoints(this.items, {this.max = 80, this.fileClosed = false});
  int get total => items.values.fold(0, (a, b) => a + b);
}

class Course {
  final String name;
  final DateTime? start;
  final DateTime? end;
  const Course(this.name, this.start, this.end);
}

class ThanksLetter {
  final String number;
  final DateTime? date;
  final String details;
  const ThanksLetter(this.number, this.date, this.details);
}

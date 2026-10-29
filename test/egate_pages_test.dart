import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idc_app/data/api.dart';
import 'package:idc_app/data/models.dart';

// مقتطفات من صفحات الخادم كما أرسلها المستخدم.
const _thanks = '<html lang="en" dir="rtl"><head><title>x</title></head><body><div><div><b><a href="home_page.php?eid=749044&amp;token=t"></a></b><h5>كتب الشكر</h5></div><br><ul><li></li></ul><table><thead><tr><!--<th>#</th>--><th>رقم الكتاب</th><th>تاريخ الكتاب</th><th>التفاصيل</th></tr></thead><tbody><tr><td>17533</td><td>2026-09-17</td><td><div title="6 اشهر كتاب رئاسة الوزراء"> 6 اشهر كتاب رئاسة الوزراء </div></td></tr><tr><td>3184</td><td>2026-08-16</td><td><div title=""></div></td></tr></tbody></table></div></body></html>';
const _train = '<html><head></head><body><h5>الدورات</h5><table><thead><tr><th>الدورة</th><th>بداية الدورة</th><th>نهاية الدورة</th></tr></thead><tbody><tr><td><strong>مكافحة الفساد في ضوء التشريعات </strong></td><td><strong>2026-02-15</strong></td><td><strong>2026-02-19</strong></td></tr><tr><td><strong>الاسعافات الاولية HSE </strong></td><td><strong>2025-12-14</strong></td><td><strong>2025-12-18</strong></td></tr></tbody></table><script> document.querySelectorAll(".date"); </script></body></html>';
const _poll = '<html lang="ar" dir="rtl"><head><title>استبيان</title></head><body><main role="main"><div><b><a href="home_page.php?eid=749044"></a></b></div><div>استبيان</div><center><h3>لا يوجد استبيان حاليا</h3></center></main></body></html>';

class _Fake implements HttpClientAdapter {
  final requests = <String>[];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(o.uri.path.split('/').last);
    final html = switch (o.uri.path.split('/').last) {
      'appreciation.php' => _thanks,
      'train.php' => _train,
      'poll.php' => _poll,
      _ => '',
    };
    return ResponseBody.fromString(html, 200, headers: {
      'content-type': ['text/html; charset=utf-8'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('التشكرات والدورات والاستبيان تُطلب مباشرة', () async {
    final fake = _Fake();
    final dio = Dio(BaseOptions(baseUrl: Endpoints.base, responseType: ResponseType.plain))..httpClientAdapter = fake;
    final repo = ApiRepository(dio: dio)..attach(const User(id: '749044', nationalId: '1', displayName: 'x', token: 't'));

    final letters = await repo.thanksLetters();
    expect(letters.length, 2);
    expect(letters[0].number, '17533');
    expect(letters[0].details, '6 اشهر كتاب رئاسة الوزراء');

    final courses = await repo.courses();
    expect(courses.length, 2);
    expect(courses[1].name, 'الاسعافات الاولية HSE');
    expect(courses[0].start, DateTime(2026, 2, 15));

    final poll = await repo.servicePage('الاستبيان');
    expect(poll.lines, ['لا يوجد استبيان حاليا']);
    expect(fake.requests, ['appreciation.php', 'train.php', 'poll.php']);
  });
}

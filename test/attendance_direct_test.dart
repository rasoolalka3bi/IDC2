import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idc_app/app/format.dart';
import 'package:idc_app/data/api.dart';
import 'package:idc_app/data/models.dart';

/// خادم وهمي يحاكي صفحة الحضور كما أرسل المستخدم مصدرها: الجلسة تبدأ من
/// قائمة الخدمات، والصفحة تعرض الشهر الحالي، وغيره بنموذج POST مع رمز حماية.
class _FakeEgate implements HttpClientAdapter {
  final requests = <String>[];
  var csrf = 0;

  String page(int y, int m) {
    final day = (int d, String inner) => '<td><span>$d</span>$inner</td>';
    final times = '<table><!--<tr><th><span>د</span></th></tr>--><tbody><tr><td>7:25</td></tr><tr><td>-:-</td></tr></tbody></table>';
    return '<html><body><form name="ss" method="post" action="/application/v2/api/egate/monthly_attends.php">'
        '<input type="hidden" name="csrf_token" value="tok${++csrf}"><input type="hidden" name="eid_n" value="749044">'
        '<select name="Y"><option value="2026"> 2026 </option></select><select name="M"><option value="1"> 1 </option></select>'
        '<button type="submit" name="veiw"> عرض </button></form><ul><li> / </li></ul>'
        '<h3><i></i>${monthName(m).replaceAll('أ', 'ا')} $y </h3><table><tbody><tr><th>الاحد</th><th>الاثنين</th><th>الثلاثاء</th>'
        '<th>الاربعاء</th><th>الخميس</th><th>الجمعة</th><th>السبت</th></tr>'
        '<tr><td>&nbsp;</td>${day(1, '<span align="center">N</span>')}${day(2, times)}${day(3, times)}</tr></tbody></table></body></html>';
  }

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final path = o.uri.path;
    final cookie = o.headers['Cookie'] as String? ?? '';
    requests.add('${o.method} $path');
    if (path.endsWith('home_page.php')) {
      return ResponseBody.fromString('menu', 200, headers: {
        'set-cookie': ['PHPSESSID=abc; path=/'],
      });
    }
    if (!cookie.contains('PHPSESSID=abc')) return ResponseBody.fromString('<form></form>', 200);
    if (o.method == 'POST') {
      final form = Uri.splitQueryString(utf8.decode(await body!.expand((b) => b).toList()));
      if (form['csrf_token'] != 'tok$csrf') return ResponseBody.fromString(page(2026, 10), 200);
      return ResponseBody.fromString(page(int.parse(form['Y']!), int.parse(form['M']!)), 200);
    }
    final now = DateTime.now();
    return ResponseBody.fromString(page(now.year, now.month), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('الحضور يُطلب من الخادم مباشرة بالجلسة ورمز الحماية', () async {
    final fake = _FakeEgate();
    final dio = Dio(BaseOptions(baseUrl: Endpoints.base, responseType: ResponseType.plain))..httpClientAdapter = fake;
    final repo = ApiRepository(dio: dio)
      ..attach(const User(id: '749044', nationalId: '1', displayName: 'x', token: 't'));
    final now = DateTime.now();

    final cur = await repo.attendance(now.year, now.month);
    expect(cur.length, 3);
    expect(cur[0].holiday, isTrue);
    expect(cur[1].checkIn, '7:25');
    expect(fake.requests, ['GET /application/v2/api/egate/home_page.php', 'GET /application/v2/api/egate/monthly_attends.php']);

    final prev = DateTime(now.year, now.month - 3);
    final other = await repo.attendance(prev.year, prev.month);
    expect(other.length, 3);
    expect(other[0].day, DateTime(prev.year, prev.month, 1));
    // شهر آخر بطلب واحد فقط على الجلسة نفسها.
    expect(fake.requests.length, 3);
    expect(fake.requests.last, 'POST /application/v2/api/egate/monthly_attends.php');
  });
}

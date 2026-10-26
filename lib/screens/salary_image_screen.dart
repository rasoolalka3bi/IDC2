import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/theme.dart';
import '../data/api.dart';
import '../widgets/common.dart';

/// يعرض صفحة توليد القصاصة الرسمية كما كان يفعل التطبيق الأصلي، وينتظر
/// رابط الصورة الذي ترسله الصفحة عبر قناة ReceiveMessage ثم يعيد الصورة.
/// إن لم ترسل الصفحة الرابط يُبحث فيها عن صورة القصاصة أو لوحة رسمها.
class SalaryImageScreen extends StatefulWidget {
  final int year;
  final int month;
  const SalaryImageScreen({super.key, required this.year, required this.month});

  static Future<Uint8List?> open(BuildContext context, int year, int month) => Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      builder: (_) => SalaryImageScreen(year: year, month: month),
    ),
  );

  @override
  State<SalaryImageScreen> createState() => _SalaryImageScreenState();
}

class _SalaryImageScreenState extends State<SalaryImageScreen> {
  static const _timeout = Duration(seconds: 40);

  /// يعيد بيانات أكبر صورة أو لوحة رسم في الصفحة إن كانت بحجم قصاصة.
  static const _findImage = '''
(function(){
  var best=null, area=0;
  [].forEach.call(document.querySelectorAll('img,canvas'),function(e){
    var w=e.naturalWidth||e.width, h=e.naturalHeight||e.height;
    if(w>=600 && h>=400 && w*h>area){best=e; area=w*h;}
  });
  if(!best) return '';
  try{
    if(best.tagName==='CANVAS') return best.toDataURL('image/png');
    var cv=document.createElement('canvas'); cv.width=best.naturalWidth; cv.height=best.naturalHeight;
    cv.getContext('2d').drawImage(best,0,0); return cv.toDataURL('image/png');
  }catch(e){ return best.src||''; }
})();''';

  late final WebViewController _web;
  final _log = <String>[];
  Timer? _timer;
  Timer? _poll;
  bool _done = false;
  bool _downloading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('ReceiveMessage', onMessageReceived: (m) => _receive(m.message))
      ..setOnConsoleMessage((m) => _note('console: ${m.message}'))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _note('تم تحميل الصفحة');
            _poll ??= Timer.periodic(const Duration(seconds: 3), (_) => _tryPage());
          },
          onHttpError: (e) => _note('HTTP ${e.response?.statusCode}'),
          onWebResourceError: (e) {
            _note('خطأ: ${e.description}');
            if (e.isForMainFrame ?? true) _fail('تعذر فتح صفحة القصاصة: ${e.description}');
          },
        ),
      );
    _start();
  }

  void _start() {
    final url = context.read<AppState>().repo.salaryImagePage(widget.year, widget.month);
    if (url == null) {
      _fail('القصاصة الرسمية غير متاحة في الوضع التجريبي');
      return;
    }
    _note('فتح الصفحة');
    _timer = Timer(_timeout, () => _fail('لم يرسل الخادم صورة القصاصة خلال ${_timeout.inSeconds} ثانية'));
    _web.loadRequest(url);
  }

  void _note(String line) {
    if (_log.length < 60) _log.add(line);
  }

  Future<void> _tryPage() async {
    if (_done || _downloading) return;
    try {
      final r = await _web.runJavaScriptReturningResult(_findImage);
      var v = '$r';
      if (v.startsWith('"')) v = jsonDecode(v) as String;
      if (v.isNotEmpty) _receive(v);
    } catch (_) {}
  }

  Future<void> _receive(String message) async {
    if (_done || _downloading) return;
    _note('وصلت رسالة: ${message.length > 120 ? '${message.substring(0, 120)}…' : message}');
    setState(() => _downloading = true);
    final bytes = await context.read<AppState>().repo.downloadSalaryImage(message, widget.year, widget.month);
    if (!mounted || _done) return;
    if (bytes == null) {
      _downloading = false;
      _fail('أرسل الخادم رابط القصاصة لكن تعذر تنزيل الصورة');
      return;
    }
    _done = true;
    _stop();
    Navigator.of(context).pop(bytes);
  }

  Future<void> _fail(String message) async {
    if (_done || !mounted) return;
    _done = true;
    _stop();
    var text = '';
    try {
      final r = await _web.runJavaScriptReturningResult(
        'document.body ? document.body.innerText.substring(0, 1500) : ""',
      );
      text = '$r';
      if (text.startsWith('"')) text = jsonDecode(text) as String;
    } catch (_) {}
    if (!mounted) return;
    setState(
      () => _error = ApiException(message, [..._log, if (text.trim().isNotEmpty) 'نص الصفحة:\n$text'].join('\n')),
    );
  }

  void _retry() {
    setState(() {
      _error = null;
      _done = false;
      _downloading = false;
      _log.clear();
    });
    _start();
  }

  void _stop() {
    _timer?.cancel();
    _poll?.cancel();
    _poll = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text('قصاصة ${monthYear(widget.year, widget.month)}')),
      body: _error != null
          ? Center(
              child: ErrorState(error: _error!, onRetry: _retry),
            )
          : Stack(
              children: [
                Positioned.fill(child: WebViewWidget(controller: _web)),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    color: c.surface,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _downloading ? 'جارٍ تنزيل القصاصة…' : 'جارٍ تجهيز القصاصة الرسمية من الخادم…',
                          style: TextStyle(color: c.ink2, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// يقرأ بيانات صفحات خادم الشركة بمتصفح مخفي ليعرضها التطبيق بتصميمه،
/// لأن الخدمات لا تتوفر إلا كصفحات ويب. تُنفَّذ المهام واحدة تلو الأخرى.
class WebScraper {
  WebScraper._();
  static final instance = WebScraper._();

  /// المتصفح الحالي، يعرضه [WebScraperHost] بحجم نقطة واحدة غير مرئية.
  final controller = ValueNotifier<WebViewController?>(null);
  Future<void> _queue = Future.value();

  /// يفتح [url] ثم ينفذ [actions] بالترتيب، وينتظر بعد كل خطوة انتقال
  /// الصفحة إن حدث، ثم يعيد نتيجة [extract] بعد فك JSON.
  /// كل خطوة تعيد 'ok' إن نجحت، وأي نتيجة أخرى توقف العملية.
  Future<Object?> run(Uri url, {List<String> actions = const [], required String extract, void Function(String)? onMessage}) {
    final job = _queue.then((_) => _run(url, actions, extract, onMessage));
    _queue = job.then((_) {}, onError: (_) {});
    return job;
  }

  Future<Object?> _run(Uri url, List<String> actions, String extract, void Function(String)? onMessage) async {
    var finished = Completer<void>();
    var started = false;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => started = true,
        onPageFinished: (_) {
          if (!finished.isCompleted) finished.complete();
        },
        onWebResourceError: (e) {
          if ((e.isForMainFrame ?? true) && !finished.isCompleted) {
            finished.completeError(Exception(e.description));
          }
        },
      ));
    if (onMessage != null) {
      c.addJavaScriptChannel('ReceiveMessage', onMessageReceived: (m) => onMessage(m.message));
    }
    controller.value = c;
    try {
      finished = Completer();
      await c.loadRequest(url);
      await finished.future.timeout(const Duration(seconds: 30));
      for (final a in actions) {
        started = false;
        finished = Completer();
        final res = await c.runJavaScriptReturningResult(a);
        if (!_text(res).contains('ok')) return null;
        // ننتظر قليلًا لمعرفة إن كانت الخطوة ستفتح صفحة جديدة.
        await Future.delayed(const Duration(milliseconds: 1200));
        if (started) await finished.future.timeout(const Duration(seconds: 30));
      }
      final out = await c.runJavaScriptReturningResult(extract);
      return _decode(out);
    } finally {
      controller.value = null;
    }
  }

  /// يفتح [url] وينتظر أول رسالة ترسلها الصفحة عبر قناة ReceiveMessage،
  /// كما تفعل صفحة قصاصة الراتب عند انتهاء توليد صورتها.
  Future<String?> waitForMessage(Uri url, {Duration timeout = const Duration(seconds: 40)}) {
    final job = _queue.then((_) async {
      final got = Completer<String?>();
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('ReceiveMessage', onMessageReceived: (m) {
          if (!got.isCompleted) got.complete(m.message);
        })
        ..setNavigationDelegate(NavigationDelegate(onWebResourceError: (e) {
          if ((e.isForMainFrame ?? true) && !got.isCompleted) got.complete(null);
        }));
      controller.value = c;
      try {
        await c.loadRequest(url);
        return await got.future.timeout(timeout, onTimeout: () => null);
      } finally {
        controller.value = null;
      }
    });
    _queue = job.then((_) {}, onError: (_) {});
    return job;
  }

  static String _text(Object? r) => '$r';

  /// أندرويد يعيد النص مغلفًا بعلامات اقتباس، فيُفك مرتين عند الحاجة.
  static Object? _decode(Object? r) {
    Object? v = r;
    for (var i = 0; i < 3 && v is String; i++) {
      try {
        v = jsonDecode(v);
      } catch (_) {
        break;
      }
    }
    return v;
  }
}

/// يضع متصفح [WebScraper] في شجرة الواجهة دون أن يراه المستخدم، لأن
/// أندرويد لا يحمّل الصفحات في متصفح غير معروض.
class WebScraperHost extends StatelessWidget {
  final Widget child;
  const WebScraperHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(textDirection: TextDirection.rtl, children: [
      child,
      ValueListenableBuilder<WebViewController?>(
        valueListenable: WebScraper.instance.controller,
        builder: (context, c, _) => c == null
            ? const SizedBox.shrink()
            : Positioned(
                left: 0,
                top: 0,
                width: 2,
                height: 2,
                child: IgnorePointer(child: Opacity(opacity: 0.01, child: WebViewWidget(controller: c))),
              ),
      ),
    ]);
  }
}

/// سكربتات قراءة صفحات الخدمات.
class ScrapeScripts {
  static String _js(String s) => jsonEncode(s);

  /// يضغط على رابط الخدمة في قائمة الخدمات. تُوحَّد صيغ الألف والياء
  /// والتاء المربوطة لأن تسميات الخادم تختلف عن تسميات التطبيق.
  static String click(String name) => '''
(function(){
  function norm(s){return (s||'').replace(/[أإآا]/g,'ا').replace(/[ىي]/g,'ي').replace(/[ةه]/g,'ه')
    .replace(/[^\\u0621-\\u064A]/g,'');}
  var want=norm(${_js(name)});
  var els=document.querySelectorAll('a,button,[onclick],li,.card,.item,div');
  for(var pass=0;pass<2;pass++){
    for(var i=0;i<els.length;i++){
      var e=els[i];
      if(e.querySelector && e.querySelector('a,button,[onclick]')) continue;
      var t=norm(e.innerText||e.textContent);
      if(!t) continue;
      if(pass===0 ? t===want : (t.indexOf(want)>=0 && t.length<=want.length+10)){
        e.click();
        return 'ok';
      }
    }
  }
  return 'no';
})();''';

  /// يختار السنة والشهر في صفحة الحضور ثم يضغط «عرض».
  static String attendanceMonth(int year, int month) => '''
(function(){
  var sels=document.querySelectorAll('select');
  function pick(sel, v){
    for(var i=0;i<sel.options.length;i++){
      var o=sel.options[i];
      if(parseInt(o.value,10)===v || parseInt(o.text,10)===v){
        sel.selectedIndex=i; sel.dispatchEvent(new Event('change',{bubbles:true})); return true;
      }
    }
    return false;
  }
  var y=false,m=false;
  for(var i=0;i<sels.length;i++){
    var s=sels[i], hasYear=false;
    for(var j=0;j<s.options.length;j++){ if(parseInt(s.options[j].text,10)>1900) hasYear=true; }
    if(hasYear) y=pick(s,$year)||y; else m=pick(s,$month)||m;
  }
  // إن لم توجد القوائم يُقرأ الشهر المعروض كما هو.
  if(!y||!m) return 'ok';
  var btns=document.querySelectorAll('button,input[type=submit],input[type=button],a');
  for(var k=0;k<btns.length;k++){
    var t=(btns[k].innerText||btns[k].value||'').trim();
    if(t.indexOf('عرض')>=0){ btns[k].click(); return 'ok'; }
  }
  var f=document.querySelector('form'); if(f){ f.submit(); }
  return 'ok';
})();''';

  /// يجمع الجداول ونص الصفحة كما هي ليفسرها التطبيق.
  static const extract = '''
(function(){
  var tables=[].map.call(document.querySelectorAll('table'),function(tb){
    return [].map.call(tb.querySelectorAll('tr'),function(tr){
      return [].map.call(tr.querySelectorAll('th,td'),function(td){return (td.innerText||td.textContent||'').trim();});
    });
  });
  var images=[].filter.call(document.querySelectorAll('img'),function(i){return (i.naturalWidth||i.width)>=200;})
    .map(function(i){return i.src;});
  return JSON.stringify({tables:tables, images:images, text:(document.body.innerText||'')});
})();''';
}

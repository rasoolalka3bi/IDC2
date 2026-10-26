import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// يقرأ بيانات صفحات خادم الشركة بمتصفح مخفي ليعرضها التطبيق بتصميمه،
/// لأن الخدمات لا تتوفر إلا كصفحات ويب. يمكن تشغيل أكثر من مهمة معًا،
/// ويُحفظ عنوان صفحة كل خدمة بعد أول فتح لتُفتح مباشرة دون المرور بالقائمة.
class WebScraper {
  WebScraper._();
  static final instance = WebScraper._();

  /// المتصفحات العاملة حاليًا، يعرضها [WebScraperHost] خلف واجهة التطبيق.
  final controllers = ValueNotifier<List<WebViewController>>(const []);
  final _pages = <String, String>{};

  void _add(WebViewController c) => controllers.value = [...controllers.value, c];
  void _remove(WebViewController c) => controllers.value = controllers.value.where((e) => e != c).toList();

  /// يفتح صفحة الخدمة [service] من قائمة الخدمات [menu] (أو من عنوانها
  /// المحفوظ)، ثم ينفذ [more] بالترتيب ويعيد نتيجة [extract] بعد فك JSON.
  Future<Object?> service(Uri menu, String service, {List<String> more = const [], required String extract}) async {
    final known = _pages[service];
    if (known != null) {
      try {
        final out = await _run(Uri.parse(known), more, extract);
        if (out is Map && '${out['text'] ?? ''}'.trim().isNotEmpty) return out;
      } catch (_) {}
      _pages.remove(service);
    }
    return _run(menu, [ScrapeScripts.click(service), ...more], extract, rememberAs: service);
  }

  Future<Object?> _run(Uri url, List<String> actions, String extract, {String? rememberAs}) async {
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
    _add(c);
    try {
      await c.loadRequest(url);
      await finished.future.timeout(const Duration(seconds: 30));
      for (var i = 0; i < actions.length; i++) {
        started = false;
        finished = Completer();
        final res = _text(await c.runJavaScriptReturningResult(actions[i]));
        if (res.contains('same')) continue;
        if (!res.contains('ok')) return null;
        // ننتظر بدء تحميل صفحة جديدة إن كانت الخطوة تفتح صفحة، وإلا نكمل.
        for (var t = 0; t < 30 && !started; t++) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (started) await finished.future.timeout(const Duration(seconds: 30));
        if (i == 0 && rememberAs != null) {
          final now = await c.currentUrl();
          if (now != null && now != url.toString()) _pages[rememberAs] = now;
        }
      }
      return _decode(await c.runJavaScriptReturningResult(extract));
    } finally {
      _remove(c);
    }
  }

  /// يفتح [url] وينتظر أول رسالة ترسلها الصفحة عبر قناة ReceiveMessage،
  /// كما تفعل صفحة قصاصة الراتب عند انتهاء توليد صورتها.
  Future<String?> waitForMessage(Uri url, {Duration timeout = const Duration(seconds: 45)}) async {
    final got = Completer<String?>();
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('ReceiveMessage', onMessageReceived: (m) {
        if (!got.isCompleted) got.complete(m.message);
      })
      ..setNavigationDelegate(NavigationDelegate(onWebResourceError: (e) {
        if ((e.isForMainFrame ?? true) && !got.isCompleted) got.complete(null);
      }));
    _add(c);
    try {
      await c.loadRequest(url);
      return await got.future.timeout(timeout, onTimeout: () => null);
    } finally {
      _remove(c);
    }
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

/// يضع متصفحات [WebScraper] بحجم الشاشة خلف واجهة التطبيق فلا يراها
/// المستخدم، لأن أندرويد لا يحمّل الصفحات في متصفح غير معروض، وبعض الصفحات
/// (مثل قصاصة الراتب) تحتاج عرضًا حقيقيًا لترسم محتواها.
class WebScraperHost extends StatelessWidget {
  final Widget child;
  const WebScraperHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(textDirection: TextDirection.rtl, children: [
      ValueListenableBuilder<List<WebViewController>>(
        valueListenable: WebScraper.instance.controllers,
        builder: (context, list, _) => Stack(children: [
          for (final c in list) Positioned.fill(child: IgnorePointer(child: WebViewWidget(key: ObjectKey(c), controller: c))),
        ]),
      ),
      child,
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
  var y=false,m=false,changed=false;
  function pick2(sel,v){var before=sel.selectedIndex; var ok=pick(sel,v); if(ok&&sel.selectedIndex!==before) changed=true; return ok;}
  for(var i=0;i<sels.length;i++){
    var s=sels[i], hasYear=false;
    for(var j=0;j<s.options.length;j++){ if(parseInt(s.options[j].text,10)>1900) hasYear=true; }
    if(hasYear) y=pick2(s,$year)||y; else m=pick2(s,$month)||m;
  }
  // إن لم توجد القوائم أو كان الشهر معروضًا أصلًا يُقرأ كما هو.
  if(!y||!m||!changed) return 'same';
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
  // الصور تُحوَّل إلى بيانات داخلية إن أمكن، لأن بعضها لا يُفتح خارج جلسة الصفحة.
  var images=[].filter.call(document.querySelectorAll('img'),function(i){return (i.naturalWidth||i.width)>=200;})
    .map(function(i){
      try{var cv=document.createElement('canvas'); cv.width=i.naturalWidth; cv.height=i.naturalHeight;
        cv.getContext('2d').drawImage(i,0,0); return cv.toDataURL('image/jpeg',0.92);}catch(e){return i.src;}
    });
  return JSON.stringify({tables:tables, images:images, text:(document.body.innerText||'')});
})();''';
}

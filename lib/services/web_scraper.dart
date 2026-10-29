import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// يقرأ بيانات صفحات خادم الشركة بمتصفح مخفي ليعرضها التطبيق بتصميمه،
/// لأن الخدمات لا تتوفر إلا كصفحات ويب. تعمل المهام واحدة تلو الأخرى كما
/// يتصفح الموظف، لأن صفحات الخادم تتشارك جلسة واحدة وتتعارض إن فُتحت معًا.
/// ويُحفظ عنوان صفحة كل خدمة بعد أول فتح لتُفتح مباشرة دون المرور بالقائمة.
class WebScraper {
  WebScraper._();
  static final instance = WebScraper._();

  /// المتصفحات العاملة حاليًا، يعرضها [WebScraperHost] خلف واجهة التطبيق.
  final controllers = ValueNotifier<List<WebViewController>>(const []);
  final _pages = <String, String>{};

  void _add(WebViewController c) => controllers.value = [...controllers.value, c];
  void _remove(WebViewController c) => controllers.value = controllers.value.where((e) => e != c).toList();

  Future<void> _queue = Future.value();

  /// صفحات تبقى مفتوحة بعد قراءتها (مثل الحضور) ليكون التنقل فيها فوريًا.
  final _kept = <String, _Tab>{};

  /// تُنسى الروابط والصفحات المفتوحة عند تغيير الحساب لأنها تحمل رمز دخوله.
  void reset() {
    _pages.clear();
    for (final t in _kept.values.toList()) {
      _drop(t);
    }
  }

  /// يفتح صفحة الخدمة [service] من قائمة الخدمات [menu] (أو من عنوانها
  /// المحفوظ)، ثم ينفذ [more] بالترتيب ويعيد نتيجة [extract] بعد فك JSON.
  /// إن لم تحقق نتيجة العنوان المحفوظ [valid] تُفتح من القائمة من جديد،
  /// لأن بعض الصفحات لا تعمل كاملة إلا إذا فُتحت من القائمة. ومع [keep]
  /// تبقى الصفحة مفتوحة دقائق، فتُنفذ الطلبات التالية عليها مباشرة.
  Future<Object?> service(
    Uri menu,
    String service, {
    List<String> more = const [],
    required String extract,
    bool Function(Map page)? valid,
    bool keep = false,
  }) {
    final key = _norm(service);
    final job = _queue.then((_) async {
      bool good(Object? out) => out is Map && '${out['text'] ?? ''}'.trim().isNotEmpty && (valid == null || valid(out));
      Object? finish(_Tab t, Object? out) {
        if (keep && good(out)) {
          _hold(key, t);
        } else {
          _drop(t);
        }
        return out;
      }

      final open = keep ? _kept[key] : null;
      if (open != null) {
        open.idle?.cancel();
        try {
          final out = await _act(open, more, extract);
          if (good(out)) return finish(open, out);
        } catch (_) {}
        _drop(open);
      }
      final known = _known(service);
      if (known != null) {
        try {
          final (t, out) = await _open(Uri.parse(known), more, extract);
          if (good(out)) return finish(t, out);
          _drop(t);
        } catch (_) {}
        _pages.remove(key);
      }
      final (t, out) = await _open(menu, [ScrapeScripts.click(service), ...more], extract, rememberAs: service);
      return finish(t, out);
    });
    _queue = job.then((_) {}, onError: (_) {});
    return job;
  }

  void _hold(String key, _Tab t) {
    final old = _kept[key];
    if (old != null && old != t) _drop(old);
    _kept[key] = t;
    t.idle?.cancel();
    t.idle = Timer(const Duration(minutes: 3), () => _drop(t));
  }

  void _drop(_Tab t) {
    t.idle?.cancel();
    _kept.removeWhere((_, v) => v == t);
    _remove(t.c);
  }

  /// توحيد اسم الخدمة كما في [ScrapeScripts.click].
  static String _norm(String s) => s
      .replaceAll(RegExp('[أإآا]'), 'ا')
      .replaceAll(RegExp('[ىي]'), 'ي')
      .replaceAll(RegExp('[ةه]'), 'ه')
      .replaceAll(RegExp('[^\u0621-\u064A]'), '');

  /// روابط قائمة الخدمات مكتوبة بـ «&amp;» بدل «&»، فيصل رمز الدخول إلى
  /// الخادم باسم خاطئ وتظهر الصفحة أحيانًا بلا بيانات.
  static String fixUrl(String url) => url.replaceAll('&amp;', '&');

  String? _known(String service) {
    final want = _norm(service);
    final exact = _pages[want];
    if (exact != null) return exact;
    for (final e in _pages.entries) {
      if (e.key.contains(want) && e.key.length <= want.length + 10) return e.value;
    }
    return null;
  }

  /// يحفظ روابط كل الخدمات من صفحة القائمة، لتُفتح كل خدمة بعدها مباشرة.
  Future<void> _harvest(WebViewController c) async {
    try {
      final links = _decode(await c.runJavaScriptReturningResult(ScrapeScripts.links));
      if (links is! List) return;
      for (final l in links) {
        if (l is List && l.length == 2) {
          final name = _norm('${l[0]}');
          final href = '${l[1]}';
          if (name.isNotEmpty && href.startsWith('http')) _pages.putIfAbsent(name, () => fixUrl(href));
        }
      }
    } catch (_) {}
  }

  Future<(_Tab, Object?)> _open(Uri url, List<String> actions, String extract, {String? rememberAs}) async {
    final t = _Tab();
    _add(t.c);
    try {
      await t.c.loadRequest(url);
      await t.finished.future.timeout(const Duration(seconds: 30));
      if (rememberAs != null) await _harvest(t.c);
      return (t, await _act(t, actions, extract, rememberAs: rememberAs, from: url));
    } catch (_) {
      _drop(t);
      rethrow;
    }
  }

  Future<Object?> _act(_Tab t, List<String> actions, String extract, {String? rememberAs, Uri? from}) async {
    final c = t.c;
    for (var i = 0; i < actions.length; i++) {
      t.started = false;
      t.finished = Completer();
      var res = _text(await c.runJavaScriptReturningResult(actions[i]));
      // خطوة انتظار: تُعاد حتى يظهر المطلوب أو تنتهي المهلة ثم يُكمل.
      for (var n = 0; res.contains('retry') && n < 150; n++) {
        await Future.delayed(const Duration(milliseconds: 200));
        try {
          res = _text(await c.runJavaScriptReturningResult(actions[i]));
        } catch (_) {} // الصفحة ما زالت تُحمَّل
      }
      if (res.contains('retry')) res = 'same';
      if (res.contains('same')) continue;
      if (!res.contains('ok')) return null;
      // ننتظر بدء تحميل صفحة جديدة إن كانت الخطوة تفتح صفحة، وإلا نكمل.
      // مهلة قصيرة: التحديث داخل الصفحة نفسها لا يبدأ تحميلًا، وخطوة الانتظار
      // التالية تتكفل بالصفحة إن بدأ تحميلها متأخرًا.
      for (var n = 0; n < 5 && !t.started; n++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (t.started) await t.finished.future.timeout(const Duration(seconds: 30));
      if (i == 0 && rememberAs != null) {
        final now = await c.currentUrl();
        if (now != null && now != from.toString()) _pages[_norm(rememberAs)] = fixUrl(now);
      }
    }
    return _decode(await c.runJavaScriptReturningResult(extract));
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

/// متصفح مخفي واحد وحالة تنقله.
class _Tab {
  final c = WebViewController();
  var finished = Completer<void>();
  var started = false;
  Timer? idle;

  _Tab() {
    c
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => started = true,
          onPageFinished: (_) {
            if (!finished.isCompleted) finished.complete();
          },
          onWebResourceError: (e) {
            if ((e.isForMainFrame ?? true) && !finished.isCompleted) {
              finished.completeError(Exception(e.description));
            }
          },
        ),
      );
  }
}

/// يضع متصفحات [WebScraper] بحجم الشاشة خلف واجهة التطبيق فلا يراها
/// المستخدم، لأن أندرويد لا يحمّل الصفحات في متصفح غير معروض.
class WebScraperHost extends StatelessWidget {
  final Widget child;
  const WebScraperHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.rtl,
      children: [
        ValueListenableBuilder<List<WebViewController>>(
          valueListenable: WebScraper.instance.controllers,
          builder: (context, list, _) => Stack(
            children: [
              for (final c in list)
                Positioned.fill(
                  child: IgnorePointer(
                    child: WebViewWidget(key: ObjectKey(c), controller: c),
                  ),
                ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// سكربتات قراءة صفحات الخدمات.
class ScrapeScripts {
  static String _js(String s) => jsonEncode(s);

  /// يضغط على رابط الخدمة في قائمة الخدمات. تُوحَّد صيغ الألف والياء
  /// والتاء المربوطة لأن تسميات الخادم تختلف عن تسميات التطبيق.
  static String click(String name) =>
      '''
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

  /// روابط صفحة القائمة: [الاسم، الرابط] لكل رابط إلى صفحة داخل الموقع.
  static const links = '''
(function(){
  var out=[];
  [].forEach.call(document.querySelectorAll('a[href]'),function(a){
    var h=a.href||''; var t=(a.innerText||a.textContent||'').trim();
    if(t && h.indexOf('http')===0 && h.indexOf('#')<0 && h!==location.href) out.push([t,h]);
  });
  return JSON.stringify(out);
})();''';

  /// نص الصفحة مع نص إطاراتها الداخلية.
  static const _allText = r'''function all(){
    var t=document.body ? (document.body.innerText||'') : '';
    var fs=document.querySelectorAll('iframe,frame');
    for(var i=0;i<fs.length;i++){ try{ var d=fs[i].contentDocument; if(d&&d.body) t+='\n'+(d.body.innerText||''); }catch(e){} }
    return t;
  }''';

  static const _calendarRe = r'/(الأحد|الاحد|السبت|الخميس|الاثنين|الإثنين)/';

  /// ينتظر ظهور تقويم الحضور (أسماء أيام الأسبوع) حتى [maxMs] ملي ثانية.
  /// بعد الضغط على «عرض» ينتظر تغيّر الصفحة وثباتها، ويقبلها كما هي بعد
  /// ثلاث ثوانٍ إن كان التقويم ظاهرًا ولم يتغير (الشهر نفسه).
  static String waitForCalendar(int maxMs) =>
      '''
(function(){
  $_allText
  var t=all(), now=Date.now();
  if(!window.__idcStart) window.__idcStart=now;
  var el=now-window.__idcStart;
  var has=$_calendarRe.test(t);
  var changed=window.__idcBefore===undefined || t!==window.__idcBefore;
  var steady=t===window.__idcLast; window.__idcLast=t;
  if((has && ((changed && steady) || el>3000)) || el>=$maxMs){ window.__idcStart=0; window.__idcBefore=undefined; return 'same'; }
  return 'retry';
})();''';

  /// يختار السنة والشهر في صفحة الحضور. الصفحة تعرض الشهر الحالي فور
  /// فتحها، فلا يُضغط «عرض» إلا إذا طُلب شهر آخر أو لم يظهر التقويم.
  static String attendanceMonth(int year, int month) =>
      '''
(function(){
  var sels=document.querySelectorAll('select'), changed=false;
  function pick(sel, v){
    for(var i=0;i<sel.options.length;i++){
      var o=sel.options[i];
      if(parseInt(o.value,10)===v || parseInt(o.text,10)===v){
        if(sel.selectedIndex!==i){ sel.selectedIndex=i; changed=true; sel.dispatchEvent(new Event('change',{bubbles:true})); }
        return;
      }
    }
  }
  for(var i=0;i<sels.length;i++){
    var s=sels[i], hasYear=false;
    for(var j=0;j<s.options.length;j++){ if(parseInt(s.options[j].text,10)>1900) hasYear=true; }
    pick(s, hasYear ? $year : $month);
  }
  $_allText
  var text=all();
  if(!changed && $_calendarRe.test(text)) return 'same';
  window.__idcBefore=text; window.__idcStart=0; window.__idcLast=undefined;
  var btns=document.querySelectorAll('button,input[type=submit],input[type=button],a');
  for(var k=0;k<btns.length;k++){
    var t=(btns[k].innerText||btns[k].value||'').trim();
    if(t.indexOf('عرض')>=0){ btns[k].click(); return 'ok'; }
  }
  var f=document.querySelector('form'); if(f){ f.submit(); return 'ok'; }
  return 'same';
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
  // نص الإطارات الداخلية من الموقع نفسه يُضاف إلى نص الصفحة.
  var text=(document.body.innerText||'');
  [].forEach.call(document.querySelectorAll('iframe,frame'),function(f){
    try{ var d=f.contentDocument; if(d&&d.body) text+='\\n'+(d.body.innerText||d.body.textContent||''); }catch(e){}
  });
  // معلومات تشخيصية تظهر في «التفاصيل» عند تعذر القراءة.
  var info='URL: '+location.pathname+location.search.replace(/token=[^&]*/,'token=…');
  [].forEach.call(document.querySelectorAll('iframe,frame,form'),function(f){
    info+='\\n'+f.tagName+': '+(f.src||f.action||'')+' '+(f.target||'');
  });
  [].forEach.call(document.scripts,function(sc){
    info+='\\nSCRIPT: '+(sc.src ? sc.src : (sc.text||'').replace(/\\s+/g,' ').substring(0,1500));
  });
  return JSON.stringify({tables:tables, images:images, text:text, info:info.substring(0,6000)});
})();''';
}

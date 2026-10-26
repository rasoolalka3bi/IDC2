import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../widgets/common.dart';

/// يعرض صفحة خدمات الموظف من خادم الشركة داخل التطبيق، مع تنسيق
/// إضافي يقرّب شكلها من تصميم التطبيق إلى أن تتوفر لها واجهة بيانات.
class ServicesWebScreen extends StatefulWidget {
  final String title;

  /// صفحة أخرى من خادم الشركة بدل صفحة الخدمات، مثل صفحة استعادة كلمة المرور.
  final Uri? url;

  /// اسم الخدمة كما يظهر في قائمة الخدمات على الخادم. عند تمريره تُفتح
  /// صفحة الخدمة مباشرة بدل عرض القائمة.
  final String? serviceName;
  const ServicesWebScreen({super.key, required this.title, this.url, this.serviceName});

  @override
  State<ServicesWebScreen> createState() => _ServicesWebScreenState();
}

class _ServicesWebScreenState extends State<ServicesWebScreen> {
  WebViewController? _web;
  int _progress = 0;
  bool _failed = false;

  /// هل جرى الانتقال إلى صفحة الخدمة المطلوبة داخل القائمة؟
  bool _opening = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_web != null) return;
    final state = context.read<AppState>();
    if (state.isDemo) return;
    final c = context.colors;
    final css = _css(c);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(c.bg)
      // صفحات الخادم ترسل رسائلها للتطبيق عبر هذه القناة كما في التطبيق الأصلي.
      ..addJavaScriptChannel('ReceiveMessage', onMessageReceived: (m) {
        if (!mounted) return;
        showMessage(context, m.message);
        if (widget.url != null) Navigator.of(context).maybePop();
      })
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
        onPageStarted: (_) => mounted ? setState(() => _failed = false) : null,
        onPageFinished: (_) async {
          await _web?.runJavaScript(
            "(function(){var s=document.createElement('style');s.innerHTML=${_jsString(css)};document.head.appendChild(s);})();",
          );
          await _openService();
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() => _failed = true);
        },
        onNavigationRequest: (r) {
          final u = Uri.parse(r.url);
          if (u.host.endsWith('idc-iq.net')) return NavigationDecision.navigate;
          launchUrl(u, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(widget.url ?? state.repo.servicesPage());
  }

  /// تفتح صفحة الخدمة من قائمة الخدمات بالضغط على رابطها، لأن الخادم لا
  /// يوفر عنوانًا مباشرًا لكل خدمة.
  Future<void> _openService() async {
    final name = widget.serviceName;
    if (name == null || widget.url != null) {
      if (mounted && !_ready) setState(() => _ready = true);
      return;
    }
    if (_opening) {
      // اكتمل تحميل صفحة الخدمة بعد الضغط على رابطها.
      if (mounted && !_ready) setState(() => _ready = true);
      return;
    }
    final res = await _web?.runJavaScriptReturningResult(_clickScript(name));
    final ok = '$res'.contains('ok');
    if (!mounted) return;
    setState(() {
      _opening = ok;
      _ready = !ok;
    });
  }

  /// يبحث عن عنصر في القائمة يطابق اسم الخدمة ويضغط عليه. تُوحَّد صيغ
  /// الألف والياء والتاء المربوطة لأن تسميات الخادم تختلف عن تسميات التطبيق.
  static String _clickScript(String name) => '''
(function(){
  function norm(s){return (s||'').replace(/[أإآا]/g,'ا').replace(/[ىي]/g,'ي').replace(/[ةه]/g,'ه')
    .replace(/[^\u0621-\u064A]/g,'');}
  var want=norm(${_jsString(name)});
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

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static String _jsString(String s) => "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', ' ')}'";

  String _css(AppColors c) => '''
    html,body{background:${_hex(c.bg)}!important;color:${_hex(c.ink)}!important;font-family:"IBM Plex Sans Arabic",system-ui,sans-serif!important;}
    .card,.panel,.box,table{background:${_hex(c.surface)}!important;border-radius:18px!important;border:0!important;box-shadow:0 6px 18px rgba(14,27,42,.06)!important;}
    th{background:${_hex(c.surface2)}!important;color:${_hex(c.ink2)}!important;}
    td,th{border-color:${_hex(c.line)}!important;}
    a,button,.btn{border-radius:14px!important;}
    .btn-primary,button[type=submit]{background:${_hex(c.accent)}!important;border-color:${_hex(c.accent)}!important;}
  ''';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final web = _web;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (web != null) IconButton(onPressed: web.reload, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث'),
          const SizedBox(width: 8),
        ],
        bottom: web != null && _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress / 100, minHeight: 3, color: c.accent, backgroundColor: Colors.transparent),
              )
            : null,
      ),
      body: web == null
          ? const Center(
              child: EmptyState(
                icon: Icons.cloud_outlined,
                title: 'هذه الخدمة تعمل مع حسابك الحقيقي',
                subtitle: 'تُعرض بياناتها من خادم الشركة بعد تسجيل الدخول برقمك الوظيفي.',
              ),
            )
          : _failed
              ? ErrorState(error: 'تعذر الوصول للخادم، تأكد من الاتصال بالإنترنت', onRetry: web.reload)
              : Stack(children: [
                  Offstage(offstage: !_ready, child: WebViewWidget(controller: web)),
                  if (!_ready) const Center(child: CircularProgressIndicator()),
                ]),
    );
  }
}

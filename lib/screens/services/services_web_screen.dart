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
  const ServicesWebScreen({super.key, required this.title, this.url});

  @override
  State<ServicesWebScreen> createState() => _ServicesWebScreenState();
}

class _ServicesWebScreenState extends State<ServicesWebScreen> {
  WebViewController? _web;
  int _progress = 0;
  bool _failed = false;

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
        onPageFinished: (_) => _web?.runJavaScript(
          "(function(){var s=document.createElement('style');s.innerHTML=${_jsString(css)};document.head.appendChild(s);})();",
        ),
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
              : WebViewWidget(controller: web),
    );
  }
}

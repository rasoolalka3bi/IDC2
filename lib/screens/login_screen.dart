import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../app/theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AppState>();
      if (s.hasSavedSession && s.biometricEnabled) _biometric();
    });
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit({bool demo = false}) async {
    if (!demo && !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().signIn(_user.text.trim(), _pass.text, demo: demo);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _biometric() async {
    final state = context.read<AppState>();
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'تأكيد هويتك للدخول إلى حسابك',
        biometricOnly: true,
      );
      if (ok) await state.unlockSaved();
    } catch (_) {
      if (mounted) showMessage(context, 'تعذر استخدام البصمة، سجّل الدخول بكلمة المرور');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(children: [
        Container(
          height: size.height * .42,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c.brand, c.brand2], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(children: [
                  Hero(
                    tag: 'logo',
                    child: Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 30, offset: const Offset(0, 10))],
                      ),
                      child: Image.asset('assets/images/logo.png'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('شركة الحفر العراقية', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('بوابة الموظف الإلكترونية', style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 13.5)),
                  const SizedBox(height: 26),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                    child: Form(
                      key: _form,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _Label('الرقم الوظيفي'),
                        TextFormField(
                          controller: _user,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(hintText: 'أدخل رقمك الوظيفي', prefixIcon: Icon(Icons.badge_outlined)),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'لا يمكن ترك هذا الحقل فارغًا' : null,
                        ),
                        const SizedBox(height: 14),
                        _Label('كلمة المرور'),
                        TextFormField(
                          controller: _pass,
                          obscureText: _hide,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'أدخل كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _hide = !_hide),
                              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              tooltip: _hide ? 'إظهار' : 'إخفاء',
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'يرجى إدخال كلمة المرور' : null,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: _error == null
                              ? const SizedBox(height: 18)
                              : Container(
                                  margin: const EdgeInsets.symmetric(vertical: 14),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(12)),
                                  child: Row(children: [
                                    Icon(Icons.error_outline_rounded, color: c.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_error!, style: TextStyle(color: c.red, fontSize: 13))),
                                  ]),
                                ),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Text('تسجيل الدخول'),
                        ),
                        const SizedBox(height: 6),
                        TextButton(onPressed: _busy ? null : () => _forgot(context), child: const Text('هل نسيت كلمة المرور؟')),
                        if (state.hasSavedSession && state.biometricEnabled) ...[
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _biometric,
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: const Text('الدخول بالبصمة'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          ),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: _busy ? null : () => _submit(demo: true),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('تجربة التطبيق ببيانات تجريبية'),
                    style: TextButton.styleFrom(foregroundColor: c.ink2),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void _forgot(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ForgotSheet(),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7, right: 2),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.ink2)),
      );
}

class _ForgotSheet extends StatefulWidget {
  const _ForgotSheet();
  @override
  State<_ForgotSheet> createState() => _ForgotSheetState();
}

class _ForgotSheetState extends State<_ForgotSheet> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      await context.read<AppState>().repo.resetPassword(username: _user.text.trim(), phone: _phone.text.trim());
      nav.pop();
      if (mounted) showMessage(context, 'تم إرسال طلب استعادة كلمة المرور');
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('استعادة كلمة المرور', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('أدخل رقمك الوظيفي ورقم الهاتف المسجل لدى الشركة.', style: TextStyle(color: context.colors.ink3, fontSize: 13)),
          const SizedBox(height: 18),
          TextFormField(
            controller: _user,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'الرقم الوظيفي', prefixIcon: Icon(Icons.badge_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'لا يمكن ترك هذا الحقل فارغًا' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '07xxxxxxxxx', prefixIcon: Icon(Icons.phone_iphone_rounded)),
            validator: (v) => (v == null || v.trim().length < 10) ? 'يرجى إدخال رقم الهاتف' : null,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('إرسال'),
          ),
        ]),
      ),
    );
  }
}

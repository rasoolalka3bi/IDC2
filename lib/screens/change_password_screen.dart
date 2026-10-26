import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../app/theme.dart';
import '../widgets/common.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      await context.read<AppState>().repo.changePassword(_old.text, _new.text);
      if (!mounted) return;
      showMessage(context, 'تم تغيير كلمة المرور');
      nav.pop();
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _hide = !_hide),
            icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('تغيير كلمة المرور')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('استخدم كلمة مرور لا تقل عن 6 أحرف ولا تشاركها مع أحد.', style: TextStyle(color: c.ink3, fontSize: 13, height: 1.6)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _old,
                obscureText: _hide,
                decoration: deco('كلمة المرور الحالية'),
                validator: (v) => (v == null || v.isEmpty) ? 'يرجى إدخال كلمة المرور الحالية' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _new,
                obscureText: _hide,
                decoration: deco('كلمة المرور الجديدة'),
                validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور الجديدة قصيرة' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: _hide,
                decoration: deco('تأكيد كلمة المرور الجديدة'),
                validator: (v) => v != _new.text ? 'كلمة المرور الجديدة غير متطابقة' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('حفظ'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

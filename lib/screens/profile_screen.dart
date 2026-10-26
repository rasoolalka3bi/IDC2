import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../app/theme.dart';
import '../widgets/common.dart';
import 'change_password_screen.dart';
import 'instructions_screen.dart';
import 'shell.dart';

const appVersion = '3.0.2';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('الكاميرا'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('معرض الصور'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (file == null || !mounted) return;
    final state = context.read<AppState>();
    setState(() => _uploading = true);
    try {
      final url = await state.repo.uploadProfileImage(file.path);
      await state.updateUserImage(url);
      if (mounted) showMessage(context, 'تم تغيير صورة الملف الشخصي');
    } catch (e) {
      if (mounted) showMessage(context, '$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _toggleBiometric(bool v) async {
    final state = context.read<AppState>();
    if (!v) return state.setBiometric(false);
    final auth = LocalAuthentication();
    try {
      if (!await auth.isDeviceSupported() || !await auth.canCheckBiometrics) {
        if (mounted) showMessage(context, 'هذا الجهاز لا يدعم البصمة');
        return;
      }
      final ok = await auth.authenticate(localizedReason: 'تأكيد البصمة لتفعيل الدخول السريع', biometricOnly: true);
      if (ok) await state.setBiometric(true);
    } catch (_) {
      if (mounted) showMessage(context, 'تعذر تفعيل البصمة');
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.red),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await context.read<AppState>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final u = state.user;
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Center(
          child: Stack(clipBehavior: Clip.none, children: [
            UserAvatar(user: u, size: 92),
            if (_uploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(30)),
                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            PositionedDirectional(
              bottom: -6,
              end: -6,
              child: Material(
                color: c.surface,
                elevation: 2,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: _uploading ? null : _changePhoto,
                  child: const SizedBox(width: 34, height: 34, child: Icon(Icons.photo_camera_outlined, size: 18)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Text(u?.displayName ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          [if (u?.jobTitle != null) u!.jobTitle!, 'الرقم الوظيفي ${u?.id ?? ''}'].join(' · '),
          textAlign: TextAlign.center,
          style: TextStyle(color: c.ink3, fontSize: 12.5),
        ),
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            _MenuItem(
              icon: Icons.badge_outlined,
              tone: Tone.blue,
              title: 'معلوماتي الوظيفية',
              onTap: () => AppShell.goTo(context, AppShell.salary),
            ),
            _MenuItem(
              icon: Icons.lock_outline_rounded,
              tone: Tone.accent,
              title: 'تغيير كلمة المرور',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            ),
            _MenuItem(
              icon: Icons.fingerprint_rounded,
              tone: Tone.green,
              title: 'الدخول بالبصمة',
              trailing: Switch(value: state.biometricEnabled, onChanged: _toggleBiometric),
            ),
            _MenuItem(
              icon: Icons.dark_mode_outlined,
              tone: Tone.gold,
              title: 'المظهر',
              last: true,
              trailing: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontFamily: kFont, fontSize: 12)),
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('تلقائي')),
                  ButtonSegment(value: ThemeMode.light, label: Text('فاتح')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('داكن')),
                ],
                selected: {state.themeMode},
                onSelectionChanged: (s) => state.setThemeMode(s.first),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            _MenuItem(
              icon: Icons.info_outline_rounded,
              tone: Tone.blue,
              title: 'التعليمات',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InstructionsScreen())),
            ),
            _MenuItem(icon: Icons.logout_rounded, tone: Tone.red, title: 'تسجيل الخروج', danger: true, last: true, onTap: _logout),
          ]),
        ),
        const SizedBox(height: 16),
        Text('الإصدار $appVersion', textAlign: TextAlign.center, style: TextStyle(color: c.ink3, fontSize: 12)),
      ]),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool last;
  final bool danger;
  const _MenuItem({
    required this.icon,
    required this.tone,
    required this.title,
    this.onTap,
    this.trailing,
    this.last = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.line))),
        child: Row(children: [
          IconTile(icon, tone: tone, size: 38, radius: 12),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontSize: 14.5, color: danger ? c.red : null))),
          trailing ?? (onTap != null && !danger ? Icon(Icons.chevron_right_rounded, color: c.ink3) : const SizedBox.shrink()),
        ]),
      ),
    );
  }
}

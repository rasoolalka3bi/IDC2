import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../data/api.dart';
import '../data/models.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: dark ? .25 : .05), blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(color: Colors.black.withValues(alpha: dark ? .2 : .05), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: TextStyle(fontSize: 12.5, color: context.colors.accent, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}

enum Tone { accent, gold, green, blue, red }

extension ToneColors on Tone {
  (Color fg, Color bg) of(AppColors c) => switch (this) {
        Tone.accent => (c.accent, c.accentSoft),
        Tone.gold => (c.gold, c.goldSoft),
        Tone.green => (c.green, c.greenSoft),
        Tone.blue => (c.blue, c.blueSoft),
        Tone.red => (c.red, c.redSoft),
      };
}

class Pill extends StatelessWidget {
  final String text;
  final Tone tone;
  final IconData? icon;
  const Pill(this.text, {super.key, this.tone = Tone.accent, this.icon});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.of(context.colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}

class IconTile extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final double size;
  final double radius;
  const IconTile(this.icon, {super.key, this.tone = Tone.accent, this.size = 42, this.radius = 13});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.of(context.colors);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
      child: Icon(icon, color: fg, size: size * .48),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final User? user;
  final double size;
  const UserAvatar({super.key, this.user, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(size * .33);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(colors: [c.gold, c.accent], begin: Alignment.topRight, end: Alignment.bottomLeft),
      ),
      alignment: Alignment.center,
      child: Text(user?.initial ?? '', style: TextStyle(color: Colors.white, fontSize: size * .4, fontWeight: FontWeight.w700)),
    );
    final url = user?.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconTile(icon, size: 76, radius: 24),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: c.ink3, fontSize: 13, height: 1.6)),
        ],
        if (action != null) ...[const SizedBox(height: 18), action!],
      ]),
    );
  }
}

class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final details = error is ApiException ? (error as ApiException).details : null;
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'تعذر تحميل البيانات',
      subtitle: '$error',
      action: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
        // ما قرأه التطبيق من صفحة الخادم، لمعرفة سبب تعذر تفسيرها.
        if (details != null && details.isNotEmpty)
          TextButton(onPressed: () => _showDetails(context, details), child: const Text('التفاصيل')),
      ]),
    );
  }

  static void _showDetails(BuildContext context, String details) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: Text('تفاصيل الخطأ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: details));
                showMessage(context, 'تم النسخ');
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('نسخ'),
            ),
          ]),
          Text('انسخ هذا النص وأرسله للمطور.', style: TextStyle(color: context.colors.ink3, fontSize: 13)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .5),
            child: SingleChildScrollView(child: SelectableText(details, style: const TextStyle(fontSize: 12.5, height: 1.6))),
          ),
        ]),
      ),
    );
  }
}

/// هيكل رمادي متحرك يظهر أثناء التحميل.
class Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 10});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FadeTransition(
      opacity: Tween(begin: .45, end: 1.0).animate(_a),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Row(children: [
              const Skeleton(height: 42, width: 42, radius: 13),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Skeleton(height: 14, width: 120.0 + (i % 3) * 40),
                  const SizedBox(height: 8),
                  const Skeleton(height: 11),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// يعرض نتيجة طلب غير متزامن مع حالات التحميل والخطأ وإعادة المحاولة.
class AsyncBody<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function() reload) builder;
  final Widget? loading;
  const AsyncBody({super.key, required this.load, required this.builder, this.loading});

  @override
  State<AsyncBody<T>> createState() => AsyncBodyState<T>();
}

class AsyncBodyState<T> extends State<AsyncBody<T>> {
  late Future<T> _future = widget.load();

  Future<void> reload() async {
    final f = widget.load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return widget.loading ?? const Padding(padding: EdgeInsets.all(16), child: SkeletonList());
        }
        if (s.hasError) return ErrorState(error: s.error!, onRetry: reload);
        return widget.builder(context, s.data as T, reload);
      },
    );
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool last;
  const KeyValueRow(this.label, this.value, {super.key, this.valueColor, this.last = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.line))),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: c.ink2, fontSize: 13.5))),
        const SizedBox(width: 12),
        // القيم كلها تبدأ من العمود نفسه، والطويلة منها تلتف تحته.
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.start,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: valueColor, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ]),
    );
  }
}

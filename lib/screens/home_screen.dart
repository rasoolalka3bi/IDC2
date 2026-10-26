import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../widgets/common.dart';
import 'notice_details_screen.dart';
import 'services/catalog.dart';
import 'shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<SalarySlip?> _salary;
  late Future<List<Notice>> _news;
  Future<_Stats?>? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final state = context.read<AppState>();
    final repo = state.repo;
    _salary = _latestSalary(repo);
    _news = repo.notices();
    _stats = repo.hasNativeServices ? _loadStats() : null;
    state.refreshUnread();
  }

  Future<SalarySlip?> _latestSalary(Repository repo) async {
    final now = DateTime.now();
    for (var back = 0; back < 3; back++) {
      final d = DateTime(now.year, now.month - back);
      final slip = await repo.salary(d.year, d.month);
      if (!slip.isEmpty) return slip;
    }
    return null;
  }

  Future<_Stats?> _loadStats() async {
    final repo = context.read<AppState>().repo;
    final now = DateTime.now();
    final r = await Future.wait([repo.attendance(now.year, now.month), repo.housingPoints(), repo.thanksLetters()]);
    final days = (r[0] as List<AttendanceDay>).where((d) => d.checkIn != null).length;
    return _Stats(days, (r[1] as HousingPoints).total, (r[2] as List).length);
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_salary.catchError((_) => null), _news.catchError((_) => <Notice>[])]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final user = state.user;
    final top = MediaQuery.paddingOf(context).top;
    return RefreshIndicator(
      onRefresh: _refresh,
      edgeOffset: top,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(children: [
            Container(
              height: top + 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.brand, c.brand2], begin: Alignment.topRight, end: Alignment.bottomLeft),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, top + 12, 18, 0),
              child: Column(children: [
                Row(children: [
                  GestureDetector(onTap: () => AppShell.goTo(context, AppShell.profile), child: UserAvatar(user: user)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(greeting(), style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 12.5)),
                      Text(user?.displayName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  _BellButton(count: state.unread, onTap: () => AppShell.goTo(context, AppShell.notifications)),
                ]),
                if (state.isDemo) ...[
                  const SizedBox(height: 10),
                  Align(alignment: AlignmentDirectional.centerStart, child: Pill('وضع تجريبي: البيانات المعروضة وهمية', tone: Tone.gold)),
                ],
                SizedBox(height: state.isDemo ? 12 : 22),
                _SalaryCard(future: _salary),
              ]),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_stats != null) ...[
                FutureBuilder<_Stats?>(
                  future: _stats,
                  builder: (context, s) {
                    final d = s.data;
                    return Row(children: [
                      _StatTile(value: d?.days, label: 'يوم حضور', color: c.green),
                      const SizedBox(width: 10),
                      _StatTile(value: d?.points, label: 'نقاط الإسكان', color: c.accent),
                      const SizedBox(width: 10),
                      _StatTile(value: d?.letters, label: 'كتب شكر', color: c.gold),
                    ]);
                  },
                ),
                const SizedBox(height: 14),
              ],
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionTitle('خدماتي'),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 6,
                    childAspectRatio: .78,
                    children: [for (final s in services) _ServiceButton(s)],
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<Notice>>(
                future: _news,
                builder: (context, s) {
                  if (s.hasError || (s.hasData && s.data!.isEmpty)) return const SizedBox.shrink();
                  final n = s.data?.firstOrNull;
                  return AppCard(
                    onTap: n == null ? null : () => openNotice(context, n),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SectionTitle('آخر التبليغات', action: 'المزيد', onAction: () => AppShell.goTo(context, AppShell.notifications)),
                      if (n == null)
                        const Row(children: [Skeleton(height: 62, width: 62, radius: 14), SizedBox(width: 12), Expanded(child: Skeleton())])
                      else
                        Row(children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(colors: [c.brand2, c.accent]),
                            ),
                            child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5)),
                              const SizedBox(height: 2),
                              Text(timeAgo(n.date), style: TextStyle(color: c.ink3, fontSize: 12)),
                            ]),
                          ),
                        ]),
                    ]),
                  );
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Stats {
  final int days, points, letters;
  _Stats(this.days, this.points, this.letters);
}

class _BellButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _BellButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Badge(
            isLabelVisible: count > 0,
            smallSize: 9,
            backgroundColor: context.colors.gold,
            alignment: const AlignmentDirectional(-.45, -.45),
            child: const Center(child: Icon(Icons.notifications_none_rounded, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _SalaryCard extends StatelessWidget {
  final Future<SalarySlip?> future;
  const _SalaryCard({required this.future});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => AppShell.goTo(context, AppShell.salary),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: FutureBuilder<SalarySlip?>(
              future: future,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Skeleton(width: 140, height: 12),
                    SizedBox(height: 12),
                    Skeleton(width: 200, height: 30),
                    SizedBox(height: 16),
                    Row(children: [Expanded(child: Skeleton(height: 54, radius: 14)), SizedBox(width: 10), Expanded(child: Skeleton(height: 54, radius: 14))]),
                  ]);
                }
                final slip = s.data;
                if (s.hasError || slip == null) {
                  return Row(children: [
                    const IconTile(Icons.account_balance_wallet_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.hasError ? 'تعذر تحميل الراتب، اضغط لفتح صفحة الراتب' : 'لا توجد بيانات راتب حديثة',
                          style: TextStyle(color: c.ink2, fontSize: 13.5)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.ink3),
                  ]);
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('صافي راتب ${monthYear(slip.year, slip.month)}', style: TextStyle(color: c.ink3, fontSize: 12.5))),
                    Icon(Icons.chevron_right_rounded, color: c.ink3),
                  ]),
                  const SizedBox(height: 6),
                  _Amount(slip.net),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _Mini(label: 'المدفوعات', value: money(slip.totalPayments), color: c.green)),
                    const SizedBox(width: 10),
                    Expanded(child: _Mini(label: 'الاستقطاعات', value: money(slip.totalDeductions), color: c.red)),
                  ]),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// صافي الراتب مخفي بنجمات، ويظهر ما دام الإصبع ضاغطًا على أيقونة العين.
class _Amount extends StatefulWidget {
  final double value;
  const _Amount(this.value);

  @override
  State<_Amount> createState() => _AmountState();
}

class _AmountState extends State<_Amount> {
  bool _show = false;

  void _set(bool v) {
    if (_show != v) setState(() => _show = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const style = TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -.5);
    return Row(children: [
      _show
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: widget.value),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text.rich(
                TextSpan(children: [
                  TextSpan(text: money(v), style: style),
                  TextSpan(text: '  د.ع', style: TextStyle(fontSize: 14, color: c.ink3)),
                ]),
                style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
              ),
            )
          : Text('٭٭٭٭٭٭٭', style: style.copyWith(letterSpacing: 2, height: 1.35)),
      const SizedBox(width: 10),
      // يبتلع الضغطة حتى لا تفتح البطاقة صفحة الراتب عند إظهار المبلغ.
      GestureDetector(
        onTap: () {},
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onLongPressEnd: (_) => _set(false),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 22,
            color: c.ink3,
          ),
        ),
      ),
    ]);
  }
}

class _Mini extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Mini({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: c.ink3, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final int? value;
  final String label;
  final Color color;
  const _StatTile({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(children: [
          value == null
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Skeleton(width: 30, height: 18))
              : Text('$value', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11.5, color: context.colors.ink3)),
        ]),
      ),
    );
  }
}

class _ServiceButton extends StatelessWidget {
  final ServiceItem s;
  const _ServiceButton(this.s);
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => openService(context, s),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconTile(s.icon, tone: s.tone, size: 52, radius: 17),
        const SizedBox(height: 6),
        Text(s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: context.colors.ink2)),
      ]),
    );
  }
}

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
  Future<int>? _days, _points, _letters;

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
    if (repo.hasNativeServices) {
      // الإحصاءات تُقرأ من صفحات الخدمات بعد انتهاء الراتب، لأنها أبطأ ولا
      // يصح أن تؤخر الأهم. وكل رقم مستقل فلا يُخفي فشلُ أحدها البقية.
      final now = DateTime.now();
      final after = _salary.then((_) {}, onError: (_) {});
      _days = after
          .then((_) => repo.attendance(now.year, now.month))
          .then((d) => d.where((x) => x.checkIn != null).length);
      _points = after.then((_) => repo.housingPoints()).then((p) => p.total);
      _letters = after.then((_) => repo.thanksLetters()).then((l) => l.length);
    }
    state.refreshUnread();
  }

  Future<SalarySlip?> _latestSalary(Repository repo) async {
    final now = DateTime.now();
    Object? error;
    for (var back = 0; back < 3; back++) {
      final d = DateTime(now.year, now.month - back);
      // محاولة ثانية عند الفشل، لأن أول طلب بعد فتح التطبيق قد ينقطع.
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final slip = await repo.salary(d.year, d.month);
          if (!slip.isEmpty) return slip;
          break;
        } catch (e) {
          error = e;
        }
      }
    }
    if (error != null) throw error;
    return null;
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
          Stack(
            children: [
              Container(
                height: top + 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.brand, c.brand2],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, top + 12, 18, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => AppShell.goTo(context, AppShell.profile),
                          child: UserAvatar(user: user),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting(),
                                style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 12.5),
                              ),
                              Text(
                                user?.displayName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        _BellButton(count: state.unread, onTap: () => AppShell.goTo(context, AppShell.notifications)),
                      ],
                    ),
                    if (state.isDemo) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Pill('وضع تجريبي: البيانات المعروضة وهمية', tone: Tone.gold),
                      ),
                    ],
                    SizedBox(height: state.isDemo ? 12 : 22),
                    _SalaryCard(future: _salary),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_days != null) ...[
                  Row(
                    children: [
                      _StatTile(future: _days!, label: 'يوم حضور', color: c.green, service: services[0]),
                      const SizedBox(width: 10),
                      _StatTile(future: _points!, label: 'نقاط الإسكان', color: c.accent, service: services[1]),
                      const SizedBox(width: 10),
                      _StatTile(future: _letters!, label: 'كتب شكر', color: c.gold, service: services[2]),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FutureBuilder<List<Notice>>(
                  future: _news,
                  builder: (context, s) {
                    if (s.hasError || (s.hasData && s.data!.isEmpty)) return const SizedBox.shrink();
                    final latest = s.data?.take(3).toList();
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionTitle(
                            'آخر التبليغات',
                            action: 'عرض الكل',
                            onAction: () => AppShell.goTo(context, AppShell.notifications),
                          ),
                          if (latest == null)
                            for (var i = 0; i < 2; i++)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Skeleton(height: 46, width: 46, radius: 13),
                                    SizedBox(width: 12),
                                    Expanded(child: Skeleton()),
                                  ],
                                ),
                              )
                          else
                            for (var i = 0; i < latest.length; i++) ...[
                              if (i > 0) Divider(height: 1, color: c.line),
                              _NoticeRow(latest[i]),
                            ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  final Notice n;
  const _NoticeRow(this.n);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openNotice(context, n),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(colors: [c.brand2, c.accent]),
              ),
              child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45),
                  ),
                  const SizedBox(height: 2),
                  Text(timeAgo(n.date), style: TextStyle(color: c.ink3, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: FutureBuilder<SalarySlip?>(
              future: future,
              builder: (context, s) {
                // شريط مختصر بلا مبالغ: يخبر بصدور الراتب، والتفاصيل في تبويب الراتب.
                final loading = s.connectionState != ConnectionState.done;
                final slip = s.data;
                final String title, subtitle;
                if (loading) {
                  title = 'جارٍ التحقق من الراتب…';
                  subtitle = '';
                } else if (s.hasError) {
                  title = 'تعذر تحميل الراتب';
                  subtitle = 'اضغط لفتح تبويب الراتب';
                } else if (slip == null) {
                  title = 'لا توجد بيانات راتب حديثة';
                  subtitle = 'اضغط لاختيار شهر آخر';
                } else {
                  title = 'صدر راتب ${monthYear(slip.year, slip.month)}';
                  subtitle = 'اضغط لعرض التفاصيل وطباعة القصاصة';
                }
                return Row(
                  children: [
                    IconTile(Icons.account_balance_wallet_outlined, tone: s.hasError ? Tone.red : Tone.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: loading
                          ? const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Skeleton(width: 170, height: 14),
                                SizedBox(height: 8),
                                Skeleton(width: 120, height: 10),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(subtitle, style: TextStyle(color: c.ink3, fontSize: 12)),
                              ],
                            ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.ink3),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final Future<int> future;
  final String label;
  final Color color;
  final ServiceItem service;
  const _StatTile({required this.future, required this.label, required this.color, required this.service});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        onTap: () => openService(context, service),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            FutureBuilder<int>(
              future: future,
              builder: (context, s) => s.connectionState != ConnectionState.done
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Skeleton(width: 30, height: 18))
                  : Text(
                      s.hasData ? '${s.data}' : '—',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: color),
                    ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5, color: context.colors.ink3)),
          ],
        ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(s.icon, tone: s.tone, size: 52, radius: 17),
          const SizedBox(height: 6),
          Text(
            s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: context.colors.ink2),
          ),
        ],
      ),
    );
  }
}

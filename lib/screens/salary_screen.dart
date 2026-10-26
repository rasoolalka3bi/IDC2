import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../services/salary_pdf.dart';
import '../widgets/common.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  late DateTime _selected;
  late List<DateTime> _months;
  final _body = GlobalKey<AsyncBodyState<SalarySlip>>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _months = List.generate(24, (i) => DateTime(now.year, now.month - i));
    _selected = _months.first;
  }

  void _select(DateTime d) {
    if (d == _selected) return;
    setState(() => _selected = d);
    _body.currentState?.reload();
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final y = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('اختر السنة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          for (var y = now.year; y >= now.year - 10; y--)
            ListTile(
              title: Text('$y'),
              trailing: y == _selected.year ? Icon(Icons.check_rounded, color: context.colors.accent) : null,
              onTap: () => Navigator.pop(context, y),
            ),
        ]),
      ),
    );
    if (y == null) return;
    setState(() {
      _months = List.generate(12, (i) => DateTime(y, 12 - i)).where((d) => !d.isAfter(now)).toList();
    });
    _select(_months.first);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppState>().repo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الراتب'),
        actions: [
          IconButton(onPressed: _pickYear, icon: const Icon(Icons.calendar_month_outlined), tooltip: 'اختيار السنة'),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _months.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _MonthChip(
              date: _months[i],
              selected: _months[i] == _selected,
              showYear: i == 0 || _months[i].month == 12,
              onTap: () => _select(_months[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AsyncBody<SalarySlip>(
            key: _body,
            load: () => repo.salary(_selected.year, _selected.month),
            loading: const _SalarySkeleton(),
            builder: (context, slip, reload) => RefreshIndicator(
              onRefresh: reload,
              child: slip.isEmpty
                  ? ListView(children: const [
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'لا توجد بيانات لهذا الشهر',
                        subtitle: 'قد لا يكون راتب هذا الشهر قد صدر بعد. اختر شهرًا آخر.',
                      ),
                    ])
                  : _SlipView(slip: slip),
            ),
          ),
        ),
      ]),
    );
  }
}

class _MonthChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final bool showYear;
  final VoidCallback onTap;
  const _MonthChip({required this.date, required this.selected, required this.showYear, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.brand : c.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text(
              showYear ? '${monthName(date.month)} ${date.year}' : monthName(date.month),
              style: TextStyle(fontSize: 13, color: selected ? Colors.white : c.ink2, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlipView extends StatefulWidget {
  final SalarySlip slip;
  const _SlipView({required this.slip});

  @override
  State<_SlipView> createState() => _SlipViewState();
}

class _SlipViewState extends State<_SlipView> {
  bool _busy = false;

  /// القصاصة المعتمدة تأتي كصورة من الخادم، فتُجلب عند الحفظ أو المشاركة
  /// ويُستعاض عنها بتصميم التطبيق إن تعذر ذلك.
  Future<void> _export(SalarySlip slip, {required bool share}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      final official = await state.repo.salaryImage(slip.year, slip.month);
      if (!mounted) return;
      // بالحساب الحقيقي تُطبع القصاصة الرسمية فقط، وتصميم التطبيق للوضع التجريبي.
      if (official == null && !state.isDemo) {
        showMessage(context, 'تعذر جلب القصاصة الرسمية من الخادم، حاول مرة أخرى');
        return;
      }
      if (share) {
        await SalaryPdf.share(context, slip, official: official);
      } else {
        await SalaryPdf.save(context, slip, official: official);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final slip = widget.slip;
    final pay = slip.totalPayments;
    final ded = slip.totalDeductions;
    final total = pay + ded;
    final payShare = total == 0 ? 1.0 : pay / total;
    final ordered = [...slip.groups]..sort((a, b) => _order(a.kind).compareTo(_order(b.kind)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('صافي الراتب · ${monthYear(slip.year, slip.month)}', style: TextStyle(color: c.ink3, fontSize: 12.5)),
            const SizedBox(height: 4),
            Text.rich(TextSpan(children: [
              TextSpan(text: money(slip.net), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
              TextSpan(text: '  د.ع', style: TextStyle(fontSize: 14, color: c.ink3)),
            ])),
            if (total > 0) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(children: [
                    Expanded(flex: (payShare * 1000).round(), child: Container(color: c.green)),
                    Expanded(flex: ((1 - payShare) * 1000).round(), child: Container(color: c.red)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                _Legend(color: c.green, text: 'المدفوعات ${money(pay)}'),
                const SizedBox(width: 16),
                _Legend(color: c.red, text: 'الاستقطاعات ${money(ded)}'),
              ]),
            ],
          ]),
        ),
        for (final g in ordered) ...[
          const SizedBox(height: 14),
          _GroupCard(group: g),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _export(slip, share: false),
              icon: _busy
                  ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_outlined, size: 19),
              label: const Text('حفظ PDF'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _export(slip, share: true),
              icon: const Icon(Icons.ios_share_rounded, size: 19),
              label: const Text('مشاركة'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: c.surface, foregroundColor: c.ink),
            ),
          ),
        ]),
      ],
    );
  }

  static int _order(SalaryGroupKind k) => switch (k) {
        SalaryGroupKind.payments => 0,
        SalaryGroupKind.deductions => 1,
        SalaryGroupKind.totals => 2,
        SalaryGroupKind.other => 3,
        SalaryGroupKind.info => 4,
      };
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: context.colors.ink2)),
      ]);
}

class _GroupCard extends StatefulWidget {
  final SalaryGroup group;
  const _GroupCard({required this.group});
  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  late bool _open = widget.group.kind != SalaryGroupKind.info;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final g = widget.group;
    final color = switch (g.kind) {
      SalaryGroupKind.payments => c.green,
      SalaryGroupKind.deductions => c.red,
      _ => null,
    };
    final icon = switch (g.kind) {
      SalaryGroupKind.payments => (Icons.south_west_rounded, Tone.green),
      SalaryGroupKind.deductions => (Icons.north_east_rounded, Tone.red),
      SalaryGroupKind.info => (Icons.badge_outlined, Tone.blue),
      _ => (Icons.receipt_long_outlined, Tone.accent),
    };
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              IconTile(icon.$1, tone: icon.$2, size: 34, radius: 11),
              const SizedBox(width: 10),
              Expanded(child: Text(g.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              if (color != null) Text(money(g.sum), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _open ? .5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more_rounded, color: c.ink3),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(children: [
            for (var i = 0; i < g.items.length; i++)
              KeyValueRow(
                g.items[i].label,
                g.kind == SalaryGroupKind.info || g.items[i].amount == null ? g.items[i].value : money(g.items[i].amount!),
                valueColor: color,
                last: i == g.items.length - 1,
              ),
          ]),
        ),
      ]),
    );
  }
}

class _SalarySkeleton extends StatelessWidget {
  const _SalarySkeleton();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: const [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Skeleton(width: 150, height: 12),
            SizedBox(height: 12),
            Skeleton(width: 210, height: 30),
            SizedBox(height: 16),
            Skeleton(height: 10),
          ]),
        ),
        SizedBox(height: 14),
        SkeletonList(count: 3),
      ]);
}

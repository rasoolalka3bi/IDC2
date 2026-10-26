import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import 'services_web_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selected = DateTime.now();
  final _body = GlobalKey<AsyncBodyState<List<AttendanceDay>>>();

  void _shift(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(DateTime.now())) return;
    setState(() {
      _month = next;
      _selected = null;
    });
    _body.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.read<AppState>().repo;
    final canNext = DateTime(_month.year, _month.month + 1).isBefore(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('الحضور'), actions: const [OriginalPageButton('الحضور'), SizedBox(width: 8)]),
      body: AsyncBody<List<AttendanceDay>>(
        key: _body,
        load: () => repo.attendance(_month.year, _month.month),
        builder: (context, days, reload) {
          final present = days.where((d) => d.checkIn != null).toList();
          final late = present.where((d) => d.late).length;
          final avg = present.isEmpty
              ? '-'
              : () {
                  final mins = present.map((d) {
                    final p = d.checkIn!.split(':');
                    return int.parse(p[0]) * 60 + int.parse(p[1]);
                  }).reduce((a, b) => a + b) ~/ present.length;
                  return '${mins ~/ 60}:${(mins % 60).toString().padLeft(2, '0')}';
                }();
          AttendanceDay? sel;
          for (final d in days) {
            if (_selected != null && _same(d.day, _selected!)) sel = d;
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              AppCard(
                child: Column(children: [
                  Row(children: [
                    IconButton.filledTonal(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded), tooltip: 'الشهر السابق'),
                    Expanded(
                      child: Text(monthYear(_month.year, _month.month),
                          textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    IconButton.filledTonal(
                      onPressed: canNext ? () => _shift(1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: 'الشهر التالي',
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _Summary(value: '${present.length}', label: 'حضور', color: c.green),
                    const SizedBox(width: 8),
                    _Summary(value: '$late', label: 'تأخير', color: c.gold),
                    const SizedBox(width: 8),
                    _Summary(value: avg, label: 'متوسط الدخول', color: c.ink),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  _Calendar(
                    month: _month,
                    days: days,
                    selected: _selected,
                    onSelect: (d) => setState(() => _selected = d),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 16, alignment: WrapAlignment.center, children: [
                    _Legend(c.green, 'في الوقت'),
                    _Legend(c.gold, 'تأخير'),
                    _Legend(c.ink3, 'عطلة أو إجازة'),
                  ]),
                ]),
              ),
              if (sel != null) ...[
                const SizedBox(height: 14),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SectionTitle('${arabicWeekdays[sel.day.weekday - 1]} ${dayMonth(sel.day)}'),
                    if (sel.holiday)
                      Text('عطلة رسمية', style: TextStyle(color: c.ink3))
                    else ...[
                      KeyValueRow('وقت الدخول', sel.checkIn ?? 'لا يوجد', valueColor: sel.checkIn == null ? c.ink3 : (sel.late ? c.gold : c.green)),
                      KeyValueRow('وقت الخروج', sel.checkOut ?? 'لم يُسجل بعد', valueColor: sel.checkOut == null ? c.ink3 : null, last: true),
                    ],
                  ]),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }

  static bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Calendar extends StatelessWidget {
  final DateTime month;
  final List<AttendanceDay> days;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  const _Calendar({required this.month, required this.days, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const heads = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
    // الأسبوع يبدأ بالأحد كما في تقويم الشركة.
    final lead = DateTime(month.year, month.month, 1).weekday % 7;
    final today = DateTime.now();
    final cells = <Widget>[
      for (final h in heads) Center(child: Text(h, style: TextStyle(fontSize: 10.5, color: c.ink3))),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (final d in days) _cell(context, d, today),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      childAspectRatio: .82,
      children: cells,
    );
  }

  Widget _cell(BuildContext context, AttendanceDay d, DateTime today) {
    final c = context.colors;
    final future = d.day.isAfter(today);
    final isToday = d.day.year == today.year && d.day.month == today.month && d.day.day == today.day;
    final isSel = selected != null && d.day.year == selected!.year && d.day.month == selected!.month && d.day.day == selected!.day;
    Color bg = c.surface2, fg = c.ink;
    String sub = '';
    Border? border;
    if (d.holiday) {
      bg = Colors.transparent;
      fg = c.ink3;
      sub = 'عطلة';
      border = Border.all(color: c.line);
    } else if (d.checkIn != null) {
      (fg, bg) = d.late ? (c.gold, c.goldSoft) : (c.green, c.greenSoft);
      sub = d.checkIn!;
    } else if (future) {
      fg = c.ink3;
    } else {
      bg = Colors.transparent;
      fg = c.ink3;
      sub = 'إجازة';
      border = Border.all(color: c.line);
    }
    if (isSel || isToday) border = Border.all(color: c.accent, width: isSel ? 2 : 1.2);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: future ? null : () => onSelect(d.day),
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: border),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${d.day.day}', style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12.5)),
          if (sub.isNotEmpty) Text(sub, style: TextStyle(color: fg, fontSize: 9.5)),
        ]),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Summary({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: TextStyle(fontSize: 11.5, color: c.ink3)),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend(this.color, this.text);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, color: context.colors.ink2)),
      ]);
}

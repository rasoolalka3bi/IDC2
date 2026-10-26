import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// سجلي الوظيفي: الدورات وكتب الشكر.
class RecordsScreen extends StatelessWidget {
  final int initialTab;
  const RecordsScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.read<AppState>().repo;
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجلي الوظيفي'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(11)),
                labelColor: Colors.white,
                unselectedLabelColor: c.ink2,
                labelStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13.5),
                tabs: const [Tab(text: 'الدورات', height: 38), Tab(text: 'كتب الشكر', height: 38)],
              ),
            ),
          ),
        ),
        body: TabBarView(children: [
          AsyncBody<List<Course>>(
            load: repo.courses,
            builder: (context, list, reload) => RefreshIndicator(
              onRefresh: reload,
              child: list.isEmpty
                  ? ListView(children: const [EmptyState(icon: Icons.menu_book_rounded, title: 'لا توجد دورات مسجلة')])
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                      AppCard(child: Column(children: [for (var i = 0; i < list.length; i++) _CourseRow(list[i], last: i == list.length - 1)])),
                    ]),
            ),
          ),
          AsyncBody<List<ThanksLetter>>(
            load: repo.thanksLetters,
            builder: (context, list, reload) => RefreshIndicator(
              onRefresh: reload,
              child: list.isEmpty
                  ? ListView(children: const [EmptyState(icon: Icons.workspace_premium_outlined, title: 'لا توجد كتب شكر')])
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                      AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Column(children: [for (var i = 0; i < list.length; i++) _LetterRow(list[i], last: i == list.length - 1)]),
                      ),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final Course course;
  final bool last;
  const _CourseRow(this.course, {this.last = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = course.end != null && course.end!.isBefore(DateTime.now());
    final dot = done ? c.green : c.accent;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 22,
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 14,
              height: 14,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface, border: Border.all(color: dot, width: 3)),
            ),
            if (!last) Expanded(child: Container(width: 2, color: c.line)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.5)),
              const SizedBox(height: 4),
              Row(children: [
                Text(
                  '${dateStr(course.start)}  ←  ${dateStr(course.end)}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: c.ink3, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Pill(done ? 'مكتملة' : 'قادمة', tone: done ? Tone.green : Tone.accent),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _LetterRow extends StatelessWidget {
  final ThanksLetter l;
  final bool last;
  const _LetterRow(this.l, {this.last = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.line))),
      child: Row(children: [
        const IconTile(Icons.workspace_premium_outlined, tone: Tone.gold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.details.isEmpty ? 'كتاب شكر' : l.details, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 3),
            Wrap(spacing: 10, children: [
              Text('رقم ${l.number}', style: TextStyle(color: c.ink3, fontSize: 12)),
              Text(dateStr(l.date), textDirection: TextDirection.ltr, style: TextStyle(color: c.ink3, fontSize: 12)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

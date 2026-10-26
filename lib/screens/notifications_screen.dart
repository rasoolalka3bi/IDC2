import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../app/format.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/paged_list.dart';
import 'inquiry_screen.dart';
import 'notice_details_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final repo = state.repo;
    final notices = PagedList<Notice>(
      key: ValueKey('n${state.isDemo}'),
      fetch: (p) async {
        final list = await repo.notices(page: p);
        if (p == 1) state.markAllRead();
        return list;
      },
      itemBuilder: (context, n) => _NoticeTile(n),
      empty: const EmptyState(icon: Icons.notifications_none_rounded, title: 'لا توجد تبليغات', subtitle: 'ستظهر هنا تبليغات وأخبار الشركة.'),
    );
    final unread = [
      if (state.unread > 0) Padding(padding: const EdgeInsetsDirectional.only(end: 16), child: Pill('${state.unread} جديد')),
    ];
    // خادم الشركة لا يوفر قائمة بالاستفسارات (تصل كإشعارات فقط)، فلا يظهر
    // تبويبها إلا في الوضع التجريبي.
    if (!state.isDemo) {
      return Scaffold(appBar: AppBar(title: const Text('التبليغات'), actions: unread), body: notices);
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التبليغات'),
          actions: unread,
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
                tabs: const [Tab(text: 'التبليغات', height: 38), Tab(text: 'استفساراتي', height: 38)],
              ),
            ),
          ),
        ),
        body: TabBarView(children: [
          notices,
          PagedList<Inquiry>(
            key: ValueKey('i${state.isDemo}'),
            fetch: (p) => repo.inquiries(page: p),
            itemBuilder: (context, q) => _InquiryTile(q),
            empty: const EmptyState(
              icon: Icons.forum_outlined,
              title: 'لا توجد استفسارات جديدة',
              subtitle: 'تظهر هنا استفساراتك وردود الموارد البشرية عليها.',
            ),
          ),
        ]),
      ),
    );
  }
}

(IconData, Tone) noticeIcon(NoticeKind k) => switch (k) {
      NoticeKind.salary => (Icons.account_balance_wallet_outlined, Tone.accent),
      NoticeKind.survey => (Icons.poll_outlined, Tone.gold),
      NoticeKind.bank => (Icons.account_balance_outlined, Tone.blue),
      NoticeKind.training => (Icons.menu_book_rounded, Tone.green),
      NoticeKind.general => (Icons.campaign_outlined, Tone.accent),
    };

class _NoticeTile extends StatelessWidget {
  final Notice n;
  const _NoticeTile(this.n);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, tone) = noticeIcon(n.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => openNotice(context, n),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(icon, tone: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.5))),
                if (!n.read)
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                  ),
              ]),
              if (n.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(n.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.ink2, fontSize: 12.8, height: 1.6)),
              ],
              const SizedBox(height: 6),
              Row(children: [
                if (n.imageUrl != null && n.imageUrl!.isNotEmpty) ...[
                  const Pill('مرفق', icon: Icons.attach_file_rounded),
                  const SizedBox(width: 8),
                ],
                Text(timeAgo(n.date), style: TextStyle(color: c.ink3, fontSize: 12)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InquiryTile extends StatelessWidget {
  final Inquiry q;
  const _InquiryTile(this.q);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = q.replies.isEmpty ? null : q.replies.last;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InquiryScreen(inquiry: q))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(Icons.forum_outlined, tone: q.answered ? Tone.green : Tone.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(q.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                Pill(q.answered ? 'تم الرد' : 'بانتظار الرد', tone: q.answered ? Tone.green : Tone.gold),
              ]),
              const SizedBox(height: 4),
              Text(last?.text ?? q.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.ink2, fontSize: 12.8, height: 1.6)),
              const SizedBox(height: 6),
              Text(timeAgo(last?.date ?? q.date), style: TextStyle(color: c.ink3, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}

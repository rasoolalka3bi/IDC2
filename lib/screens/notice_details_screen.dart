import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/format.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'notifications_screen.dart';

void openNotice(BuildContext context, Notice n) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoticeDetailsScreen(notice: n)));

class NoticeDetailsScreen extends StatelessWidget {
  final Notice notice;
  const NoticeDetailsScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, tone) = noticeIcon(notice.kind);
    final img = notice.imageUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل التبليغ')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconTile(icon, tone: tone),
              const SizedBox(width: 10),
              Text(notice.date == null ? '' : '${dateStr(notice.date)} · ${timeAgo(notice.date)}', style: TextStyle(color: c.ink3, fontSize: 12.5)),
            ]),
            const SizedBox(height: 14),
            Text(notice.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.5)),
            if (notice.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(notice.description, style: TextStyle(color: c.ink2, fontSize: 14.5, height: 1.9)),
            ],
          ]),
        ),
        if (img != null && img.isNotEmpty) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ImageViewer(url: img))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(children: [
                CachedNetworkImage(
                  imageUrl: img,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const Skeleton(height: 260, radius: 20),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
                PositionedDirectional(
                  bottom: 10,
                  end: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('تكبير', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final String url;
  const _ImageViewer({required this.url});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import 'services_web_screen.dart';

/// يعرض بتصميم التطبيق خدمات الشركة التي لا تحتاج شاشة خاصة، مثل الاستبيان
/// وقطع الأراضي والأرباح: نصوص الصفحة في بطاقة وصورها قابلة للتكبير.
class GenericServiceScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const GenericServiceScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.read<AppState>().repo;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [OriginalPageButton(title), const SizedBox(width: 8)]),
      body: AsyncBody<ServicePage>(
        load: () => repo.servicePage(title),
        builder: (context, page, reload) {
          if (page.isEmpty) {
            return Center(child: EmptyState(icon: icon, title: 'لا توجد بيانات حاليًا'));
          }
          // صفحة نصها سطر أو سطران فقط هي رسالة، مثل «لا يوجد استبيان حاليا».
          final message = page.images.isEmpty && page.lines.length <= 3;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              if (message)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: icon,
                    title: page.lines.first,
                    subtitle: page.lines.length > 1 ? page.lines.skip(1).join('\n') : null,
                  ),
                )
              else ...[
                for (final url in page.images) ...[
                  _ImageCard(url: url, title: title),
                  const SizedBox(height: 14),
                ],
                if (page.lines.isNotEmpty)
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final (i, l) in page.lines.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text(
                            l,
                            style: TextStyle(
                              fontSize: i == 0 ? 15.5 : 13.5,
                              fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400,
                              color: i == 0 ? c.ink : c.ink2,
                              height: 1.7,
                            ),
                          ),
                        ),
                    ]),
                  ),
              ],
            ]),
          );
        },
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final String url;
  final String title;
  const _ImageCard({required this.url, required this.title});

  /// الصور تأتي من الصفحة كبيانات داخلية (data:) غالبًا، أو كرابط عادي.
  Widget _image({BoxFit? fit, Widget? error}) {
    if (url.startsWith('data:')) {
      final bytes = UriData.parse(url).contentAsBytes();
      return Image.memory(bytes, fit: fit, errorBuilder: (_, _, _) => error ?? const SizedBox());
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, _) => const AspectRatio(aspectRatio: 1.4, child: Skeleton()),
      errorWidget: (_, _, _) => error ?? const SizedBox(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(title)),
            body: InteractiveViewer(maxScale: 5, child: Center(child: _image())),
          ),
        )),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _image(
            error: AspectRatio(
              aspectRatio: 1.4,
              child: Center(child: Icon(Icons.broken_image_outlined, color: c.ink3, size: 40)),
            ),
          ),
        ),
      ),
    );
  }
}

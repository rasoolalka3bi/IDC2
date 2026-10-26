import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class HousingPointsScreen extends StatelessWidget {
  const HousingPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.read<AppState>().repo;
    return Scaffold(
      appBar: AppBar(title: const Text('نقاط الإسكان')),
      body: AsyncBody<HousingPoints>(
        load: repo.housingPoints,
        builder: (context, p, reload) {
          final top = p.items.values.fold<int>(1, math.max);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: p.total / p.max),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => CustomPaint(
                        painter: _Ring(v, c.accent, c.surface2),
                        child: Center(child: Text('${p.total}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('مجموع النقاط', style: TextStyle(color: c.ink3, fontSize: 12.5)),
                      const SizedBox(height: 4),
                      Text('من أصل ${p.max} نقطة', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      if (p.fileClosed) const Pill('ملف الإسكان مغلق', tone: Tone.gold),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionTitle('تفاصيل النقاط'),
                  for (final e in p.items.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        SizedBox(width: 110, child: Text(e.key, style: TextStyle(color: c.ink2, fontSize: 13.5))),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: e.value / top),
                              duration: const Duration(milliseconds: 800),
                              builder: (context, v, _) => LinearProgressIndicator(
                                value: v,
                                minHeight: 8,
                                color: c.accent,
                                backgroundColor: c.surface2,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          child: Text('${e.value}', textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                ]),
              ),
              if (p.fileClosed) ...[
                const SizedBox(height: 14),
                AppCard(
                  color: c.goldSoft,
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, color: c.gold),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('تم الانتهاء من تغذية بيانات الإسكان، ولا يمكن تعديل النقاط حاليًا.', style: TextStyle(fontSize: 13, height: 1.7)),
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

class _Ring extends CustomPainter {
  final double value;
  final Color color, track;
  _Ring(this.value, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value.clamp(0, 1), false, p..color = color);
  }

  @override
  bool shouldRepaint(_Ring old) => old.value != value || old.color != color;
}

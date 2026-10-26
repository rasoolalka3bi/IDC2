import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../widgets/common.dart';

class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  static const _items = [
    (Icons.login_rounded, 'تسجيل الدخول', 'استخدم رقمك الوظيفي وكلمة المرور التي زودتك بها الشركة. يمكنك تفعيل الدخول بالبصمة من صفحة حسابي.'),
    (Icons.account_balance_wallet_outlined, 'الراتب', 'اختر الشهر من الأعلى لعرض قصاصة الراتب، ويمكنك حفظها PDF أو مشاركتها.'),
    (Icons.grid_view_rounded, 'الخدمات', 'تجد في الشاشة الرئيسية الحضور ونقاط الإسكان والدورات والتشكرات وبقية الخدمات.'),
    (Icons.notifications_none_rounded, 'التبليغات', 'تصلك تبليغات الشركة وردود الموارد البشرية على استفساراتك في تبويب التبليغات.'),
    (Icons.lock_outline_rounded, 'الأمان', 'لا تشارك كلمة المرور مع أحد، وسجّل الخروج إذا كنت تستخدم جهازًا ليس لك.'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('التعليمات')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (icon, title, body) = _items[i];
          return AppCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconTile(icon, tone: Tone.values[i % 4]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(body, style: TextStyle(color: c.ink2, fontSize: 13.5, height: 1.7)),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../widgets/common.dart';
import 'attendance_screen.dart';
import 'generic_service_screen.dart';
import 'housing_points_screen.dart';
import 'records_screen.dart';
import 'services_web_screen.dart';

class ServiceItem {
  final String title;
  final IconData icon;
  final Tone tone;

  /// الشاشة الأصلية المصممة لهذه الخدمة، إن وُجدت بيانات لها.
  final WidgetBuilder? native;

  const ServiceItem(this.title, this.icon, this.tone, [this.native]);
}

final services = <ServiceItem>[
  ServiceItem('الحضور', Icons.fingerprint_rounded, Tone.green, (_) => const AttendanceScreen()),
  ServiceItem('نقاطي', Icons.home_work_outlined, Tone.accent, (_) => const HousingPointsScreen()),
  ServiceItem('التشكرات', Icons.workspace_premium_outlined, Tone.gold, (_) => const RecordsScreen(initialTab: 1)),
  ServiceItem('الدورات', Icons.menu_book_rounded, Tone.blue, (_) => const RecordsScreen(initialTab: 0)),
  ServiceItem('الأرباح', Icons.trending_up_rounded, Tone.gold, (_) => const GenericServiceScreen(title: 'الأرباح', icon: Icons.trending_up_rounded)),
  ServiceItem('قطع الأراضي', Icons.location_on_outlined, Tone.green, (_) => const GenericServiceScreen(title: 'قطع الأراضي', icon: Icons.location_on_outlined)),
  ServiceItem('الاستبيان', Icons.poll_outlined, Tone.blue, (_) => const GenericServiceScreen(title: 'الاستبيان', icon: Icons.poll_outlined)),
  ServiceItem('الزمنيات', Icons.schedule_rounded, Tone.accent, (_) => const GenericServiceScreen(title: 'الزمنيات', icon: Icons.schedule_rounded)),
];

void openService(BuildContext context, ServiceItem s) {
  final repo = context.read<AppState>().repo;
  final builder = repo.hasNativeServices && s.native != null
      ? s.native!
      : (BuildContext _) => ServicesWebScreen(title: s.title, serviceName: s.title);
  Navigator.of(context).push(MaterialPageRoute(builder: builder));
}

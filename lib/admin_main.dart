import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const adminBackground = Color(0xFF0B0E12);
const adminCard = Color(0xFF181D24);
const adminGold = Color(0xFFDBB879);
const adminText = Color(0xFFF7F3ED);
const adminMuted = Color(0xFFB1B8C2);
const adminPanelUrl = 'https://jawlah-real-estate-5sz9.hatchable.site';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JawlahAdminApp());
}

class JawlahAdminApp extends StatelessWidget {
  const JawlahAdminApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'جولة | الإدارة',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: adminBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: adminGold,
        brightness: Brightness.dark,
        surface: adminCard,
      ),
    ),
    home: const Directionality(
      textDirection: TextDirection.rtl,
      child: AdminLauncherScreen(),
    ),
  );
}

/// Uses Android's Chrome Custom Tabs to preserve the browser's secure login
/// and cookies. No admin passwords or customer financial records are stored
/// inside the APK. The remote admin routes require Hatchable admin access.
class AdminLauncherScreen extends StatefulWidget {
  const AdminLauncherScreen({super.key});

  @override
  State<AdminLauncherScreen> createState() => _AdminLauncherScreenState();
}

class _AdminLauncherScreenState extends State<AdminLauncherScreen> {
  bool opening = false;

  Future<void> openDashboard({bool external = false}) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final uri = Uri.parse(adminPanelUrl);
      bool opened = await launchUrl(
        uri,
        mode: external ? LaunchMode.externalApplication : LaunchMode.inAppBrowserView,
      );
      if (!opened && !external) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('مش قادر أفتح لوحة التحكم. اتأكد إن Chrome مثبت وإن الإنترنت شغال.'),
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تعذر فتح لوحة الإدارة. جرّب زر فتح عبر Chrome.'),
      ));
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Widget service(IconData icon, String title, String description) =>
    Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: adminCard,
        border: Border.all(color: const Color(0xFF373D46)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 43, height: 43,
          decoration: BoxDecoration(
            color: const Color(0xFF3D3020),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: adminGold, size: 23),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: adminText)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(
              fontSize: 12, color: adminMuted, height: 1.45)),
          ])),
      ]));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: adminBackground,
    appBar: AppBar(
      backgroundColor: adminBackground,
      centerTitle: true,
      title: const Text('جولة | الإدارة',
        style: TextStyle(color: adminGold, fontWeight: FontWeight.w900)),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 15, 22, 35),
        children: [
          Center(child: Container(
            width: 125, height: 125, padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: adminCard,
              border: Border.all(color: adminGold),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Image.asset('assets/branding/jawlah_launcher.png',
              fit: BoxFit.contain),
          )),
          const SizedBox(height: 20),
          const Text('لوحة تحكم جولة العقارية',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adminText, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('إدارة شركتك وتطبيق العملاء من الموبايل',
            textAlign: TextAlign.center,
            style: TextStyle(color: adminMuted, fontSize: 14)),
          const SizedBox(height: 25),
          service(Icons.home_work_outlined, 'العقارات والمشاريع',
            'أضف العقارات، الأسعار، المساحات، والصور الحقيقية.'),
          service(Icons.edit_note_outlined, 'تخصيص تطبيق العملاء',
            'غيّر واجهة التطبيق والإعلانات والعروض والأقسام الجديدة.'),
          service(Icons.groups_outlined, 'متابعة العملاء',
            'راجع العملاء والمراحل والملاحظات والزيارات.'),
          service(Icons.account_balance_wallet_outlined, 'الإيرادات والأرباح',
            'سجّل الدخل والمصروفات وراجع التقارير المالية.'),
          const SizedBox(height: 12),
          SizedBox(height: 55, child: FilledButton.icon(
            onPressed: opening ? null : () => openDashboard(),
            style: FilledButton.styleFrom(
              backgroundColor: adminGold, foregroundColor: adminBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            ),
            icon: opening ? const SizedBox.square(
              dimension: 17, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('فتح لوحة التحكم', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900)),
          )),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: opening ? null : () => openDashboard(external: true),
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text('فتح في Chrome'),
            style: TextButton.styleFrom(foregroundColor: adminGold),
          ),
          const SizedBox(height: 12),
          const Text(
            'لوحة التحكم خاصة بالمالك. يتم تسجيل الدخول عبر المتصفح الآمن، ولا يحتفظ التطبيق بكلمة مرور الإدارة أو بيانات العملاء.',
            textAlign: TextAlign.center,
            style: TextStyle(color: adminMuted, height: 1.65, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

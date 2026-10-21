import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Jawlah Luxury UI — demo properties are illustrative, not real sale offers.
// To enable authentication, provide public Supabase URL/anon key at build time.
const kBg = Color(0xFF090B0D);
const kSurface = Color(0xFF15181B);
const kSurface2 = Color(0xFF1E2022);
const kGold = Color(0xFFE5BC73);
const kGoldDark = Color(0xFFAD8649);
const kMuted = Color(0xFFB0B0B5);
const kWhite = Color(0xFFF9F7F2);
const kLine = Color(0xFF393A3C);
const kWebsite = 'https://www.jawlahre.sa';
const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const kSupabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

class Estate {
  final String id, title, city, neighborhood, type, image, description;
  final int price, area, bedrooms, baths;
  const Estate(this.id, this.title, this.city, this.neighborhood, this.type,
      this.image, this.description, this.price, this.area, this.bedrooms, this.baths);
}

const estates = <Estate>[
  Estate('villa-01', 'فيلا فاخرة مودرن', 'الرياض', 'حي النرجس', 'فلل',
    'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1200&q=85',
    'فيلا عصرية ذات مساحات رحبة وحديقة خاصة وتصميم معماري أنيق. هذا العرض توضيحي فقط.',
    5200000, 450, 6, 5),
  Estate('villa-02', 'فيلا بتصميم فاخر', 'الرياض', 'حي حطين', 'فلل',
    'https://images.unsplash.com/photo-1600047509782-20d39509f26d?auto=format&fit=crop&w=1200&q=85',
    'تصميم حديث وتشطيبات مميزة في موقع سكني راقٍ. السعر والصور بيانات تجريبية.',
    4800000, 360, 4, 5),
  Estate('flat-01', 'شقة فاخرة بإطلالة', 'الرياض', 'حي الملقا', 'شقق',
    'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?auto=format&fit=crop&w=1200&q=85',
    'شقة واسعة بتفاصيل معمارية عصرية ومساحات معيشة عملية. البيانات تجريبية.',
    1950000, 220, 3, 3),
  Estate('town-01', 'تاون هاوس حديث', 'جدة', 'أبحر الشمالية', 'فلل',
    'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1200&q=85',
    'تاون هاوس أنيق مناسب للعائلات. البيانات والصور المعروضة للشرح فقط.',
    3400000, 300, 4, 4),
  Estate('flat-02', 'شقة راقية', 'جدة', 'حي الشاطئ', 'شقق',
    'https://images.unsplash.com/photo-1600566753086-00f18fb6b3ea?auto=format&fit=crop&w=1200&q=85',
    'تشطيب عصري وموقع مميز. العرض تجريبي وليس وحدة منشورة للبيع.',
    1650000, 180, 3, 2),
  Estate('land-01', 'أرض سكنية مميزة', 'الدمام', 'حي الشاطئ', 'أراضي',
    'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1200&q=85',
    'أرض مناسبة للتطوير السكني. السعر والموقع توضيحيان وغير معتمدين.',
    1850000, 600, 0, 0),
];

String sar(int n) {
  final s = n.toString();
  return s.replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',') + ' ر.س';
}

Future<void> site() async {
  final uri = Uri.parse(kWebsite);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

void message(BuildContext context, String value) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(value), backgroundColor: kSurface2));
}

class AuthApi {
  static bool get configured => kSupabaseUrl.isNotEmpty && kSupabaseKey.isNotEmpty;
  static Map<String, String> get headers => {
    'apikey': kSupabaseKey,
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ' + kSupabaseKey,
  };
  static Future<Map<String, dynamic>> send(
      String endpoint, Map<String, dynamic> payload) async {
    if (!configured) {
      throw Exception('تسجيل الدخول الحقيقي يحتاج ربط Supabase أولاً. يمكنك استكشاف التطبيق كزائر.');
    }
    final response = await http.post(
      Uri.parse(kSupabaseUrl.replaceAll(RegExp(r'/$'), '') + endpoint),
      headers: headers,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));
    final result = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) {
      final error = result is Map
        ? (result['msg'] ?? result['error_description'] ?? result['message'] ?? result['error'])
        : null;
      throw Exception((error ?? 'تعذر إتمام العملية').toString());
    }
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }
  // First verified phone OTP creates a new user; returning numbers log in.
  static const _vault = FlutterSecureStorage();
  static String? normalizePhone(String input) {
    final digits = input.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (RegExp(r'^05\d{8}$').hasMatch(digits)) return '+966' + digits.substring(1);
    if (RegExp(r'^5\d{8}$').hasMatch(digits)) return '+966' + digits;
    if (RegExp(r'^9665\d{8}$').hasMatch(digits)) return '+' + digits;
    if (digits.startsWith('+966') && !RegExp(r'^\+9665\d{8}$').hasMatch(digits)) return null;
    if (RegExp(r'^01[0125]\d{8}$').hasMatch(digits)) return '+20' + digits.substring(1);
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(digits) ? digits : null;
  }
  static Future<void> sendPhoneCode(String phone) async {
    await send('/auth/v1/otp', {'phone': phone, 'create_user': true});
  }
  static Future<void> verifyPhone(String phone, String pin) async {
    final session = await send('/auth/v1/verify', {'phone': phone, 'token': pin, 'type': 'sms'});
    final access = session['access_token'];
    final refresh = session['refresh_token'];
    if (access is! String || access.isEmpty || refresh is! String || refresh.isEmpty) {
      throw Exception('تعذر تأكيد جلسة حسابك. حاول مرة أخرى.');
    }
    await _vault.write(key: 'access_token', value: access);
    await _vault.write(key: 'refresh_token', value: refresh);
    await _vault.write(key: 'account_phone', value: phone);
  }
  static Future<String?> restorePhone() async {
    if (!configured) return null;
    try {
      final token = await _vault.read(key: 'access_token');
      final refresh = await _vault.read(key: 'refresh_token');
      if (token == null || refresh == null) return null;
      final result = await http.get(
        Uri.parse(kSupabaseUrl.replaceAll(RegExp(r'/$'), '') + '/auth/v1/user'),
        headers: {'apikey': kSupabaseKey, 'Authorization': 'Bearer ' + token},
      ).timeout(const Duration(seconds: 12));
      if (result.statusCode == 200) {
        final user = jsonDecode(utf8.decode(result.bodyBytes));
        if (user is Map && user['phone'] is String) return user['phone'] as String;
        return await _vault.read(key: 'account_phone');
      }
      if (result.statusCode == 401 || result.statusCode == 403) {
        final updated = await send('/auth/v1/token?grant_type=refresh_token',
          {'refresh_token': refresh});
        if (updated['access_token'] is String && updated['refresh_token'] is String) {
          final phone = await _vault.read(key: 'account_phone');
          await _vault.write(key: 'access_token', value: updated['access_token'] as String);
          await _vault.write(key: 'refresh_token', value: updated['refresh_token'] as String);
          return phone;
        }
      }
    } catch (_) { /* Offline or expired: require OTP again. */ }
    return null;
  }
  static Future<void> logout() async {
    for (final key in ['access_token', 'refresh_token', 'account_phone']) {
      await _vault.delete(key: key);
    }
  }
}

void main() => runApp(const JawlahApp());

class JawlahApp extends StatelessWidget {
  const JawlahApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'جولة العقارية',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.dark(
        primary: kGold, onPrimary: kBg, surface: kSurface,
        onSurface: kWhite, secondary: kGold),
      appBarTheme: const AppBarTheme(
        backgroundColor: kBg, foregroundColor: kWhite, centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: kSurface,
        hintStyle: const TextStyle(color: kMuted),
        labelStyle: const TextStyle(color: kMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: kLine)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: kLine)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: kGold))),
    ),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl, child: child!),
    home: const AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}
class _AuthGateState extends State<AuthGate> {
  late final Future<String?> session = AuthApi.restorePhone();
  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator(color: kGold)));
      }
      final value = snapshot.data;
      if (value != null && value.isNotEmpty) return JawlahShell(username: value);
      return const WelcomePage();
    },
  );
}

Widget goldButton(String text, VoidCallback? onTap, {IconData? icon}) =>
  SizedBox(width: double.infinity, height: 56,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: kGold, foregroundColor: kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        if (icon != null) ...[
          const SizedBox(width: 12),
          Icon(icon, size: 20),
        ],
      ])));

Widget outlineButton(String text, VoidCallback? onTap, {IconData? icon}) =>
  SizedBox(width: double.infinity, height: 54,
    child: OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: kGold,
        side: const BorderSide(color: kGoldDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
      icon: Icon(icon ?? Icons.arrow_back),
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold))));

Widget brand({double size = 39}) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Image.asset('assets/branding/jawlah_launcher.png',
      height: size * 2.0, width: size * 2.0, fit: BoxFit.contain),
    const SizedBox(height: 4),
    Text('جولة العقارية', style: TextStyle(
      fontSize: size * 0.68, color: kGold, fontWeight: FontWeight.w900)),
    Text('JAWLAH REAL ESTATE', style: TextStyle(
      fontSize: size * 0.28, color: kGold,
      letterSpacing: 1.4, fontWeight: FontWeight.w600)),
  ],
);

Widget photo(String url, {double? height, BoxFit fit = BoxFit.cover}) =>
  Image.network(url, height: height, width: double.infinity, fit: fit,
    errorBuilder: (_, error, stack) => Container(
      height: height, color: kSurface2,
      child: const Center(child: Icon(Icons.villa_rounded, size: 68, color: kGoldDark))));

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(fit: StackFit.expand, children: [
      photo(estates.first.image),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xC8000000), Color(0x44000000), Color(0xF8000000)]))),
      SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 26),
        child: Column(children: [
          const Spacer(flex: 2),
          brand(size: 52),
          const Spacer(flex: 3),
          const Text('اكتشف عالم', style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w600)),
          const Text('العقارات الفاخرة', style: TextStyle(
            fontSize: 36, fontWeight: FontWeight.w900, color: kGold)),
          const SizedBox(height: 13),
          const Text('وجهتك لاكتشاف أفضل الفرص العقارية\nفي المملكة العربية السعودية',
            style: TextStyle(color: kMuted, height: 1.7, fontSize: 15),
            textAlign: TextAlign.center),
          const SizedBox(height: 35),
          goldButton('ابدأ الآن', () => Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const JawlahShell())),
            icon: Icons.arrow_back),
          const SizedBox(height: 15),
          TextButton(onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PhonePage())),
            child: const Text('إنشاء حساب أو تسجيل الدخول',
              style: TextStyle(color: kGold, fontSize: 17))),
          const SizedBox(height: 6),
        ]),
      )),
    ]),
  );
}

class PhonePage extends StatefulWidget {
  const PhonePage({super.key});
  @override State<PhonePage> createState() => _PhonePageState();
}
class _PhonePageState extends State<PhonePage> {
  final phone = TextEditingController();
  bool busy = false;
  @override void dispose() { phone.dispose(); super.dispose(); }
  Future<void> send() async {
    final formatted = AuthApi.normalizePhone(phone.text);
    if (formatted == null) {
      message(context, 'اكتب رقم جوال صحيح: 05XXXXXXXX أو +9665XXXXXXXX'); return;
    }
    setState(() => busy = true);
    try {
      await AuthApi.sendPhoneCode(formatted);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => VerifyPage(phone: formatted)));
    } catch (e) {
      if (mounted) message(context, e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إنشاء حساب أو تسجيل الدخول')),
    body: ListView(padding: const EdgeInsets.all(26), children: [
      const SizedBox(height: 35), brand(size: 32),
      const SizedBox(height: 40),
      const Text('حسابك يبدأ برقم جوالك', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text('أنشئ حسابك أو سجّل الدخول برمز تحقق SMS من غير بريد إلكتروني ولا كلمة مرور.',
        style: TextStyle(color: kMuted)),
      const SizedBox(height: 22),
      TextField(controller: phone, keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(hintText: '+966 5X XXX XXXX',
          prefixIcon: Icon(Icons.phone_android, color: kGold))),
      const SizedBox(height: 24),
      goldButton(busy ? 'جارٍ الإرسال...' : 'إرسال رمز التحقق',
        busy ? null : send),
      const SizedBox(height: 15),
      outlineButton('تصفّح كزائر', () => Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const JawlahShell()), (_) => false),
        icon: Icons.visibility_outlined),
      const SizedBox(height: 13),
      if (!AuthApi.configured) const Text('لإرسال رسائل فعلية يجب تفعيل Supabase Phone Auth ومزود SMS. حالياً يمكن التصفح كزائر.',
        textAlign: TextAlign.center, style: TextStyle(color: kGold, fontSize: 12)),
    ]),
  );
}
class VerifyPage extends StatefulWidget {
  final String phone;
  const VerifyPage({super.key, required this.phone});
  @override State<VerifyPage> createState() => _VerifyPageState();
}
class _VerifyPageState extends State<VerifyPage> {
  final pin = TextEditingController();
  bool busy = false, resending = false;
  Timer? resendTimer;
  int secondsLeft = 60;
  @override void initState() { super.initState(); startCountdown(); }
  void startCountdown() {
    resendTimer?.cancel();
    setState(() => secondsLeft = 60);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (secondsLeft <= 1) { timer.cancel(); setState(() => secondsLeft = 0); }
      else { setState(() => secondsLeft--); }
    });
  }
  @override void dispose() { resendTimer?.cancel(); pin.dispose(); super.dispose(); }
  Future<void> verify() async {
    if (!RegExp(r'^\d{6} { message(context, 'أدخل رمز التحقق المكون من 6 أرقام'); return; }
    setState(() => busy = true);
    try {
      await AuthApi.verifyPhone(widget.phone, pin.text.trim());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
        builder: (_) => JawlahShell(username: widget.phone)), (_) => false);
    } catch (e) {
      if (mounted) message(context, e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('رمز التحقق')),
    body: ListView(padding: const EdgeInsets.all(26), children: [
      const SizedBox(height: 55), brand(size: 33),
      const SizedBox(height: 45),
      const Text('أدخل رمز التحقق', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center),
      const SizedBox(height: 14),
      Text('أرسلنا الرمز إلى ' + widget.phone,
        style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
      const SizedBox(height: 30),
      TextField(controller: pin, maxLength: 6,
        keyboardType: TextInputType.number, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 30, letterSpacing: 12, color: kGold),
        decoration: const InputDecoration(hintText: '••••••', counterText: '')),
      const SizedBox(height: 24),
      goldButton(busy ? 'جارٍ التحقق...' : 'تأكيد', busy ? null : verify),
      TextButton(onPressed: secondsLeft > 0 || resending ? null : () async {
        setState(() => resending = true);
        try { await AuthApi.sendPhoneCode(widget.phone);
          if (mounted) { pin.clear(); startCountdown(); message(context, 'تم طلب رمز جديد'); }
        } catch (e) { if (mounted) message(context,
          e.toString().replaceFirst('Exception: ', '')); }
        finally { if (mounted) setState(() => resending = false); }
      }, child: Text(secondsLeft > 0 ? 'إعادة الإرسال بعد $secondsLeft ثانية' : 'إعادة إرسال الرمز',
        style: TextStyle(color: secondsLeft > 0 ? kMuted : kGold))),
    ]),
  );
}

class JawlahShell extends StatefulWidget {
  final String? username;
  const JawlahShell({super.key, this.username});
  @override State<JawlahShell> createState() => _JawlahShellState();
}
class _JawlahShellState extends State<JawlahShell> {
  final query = TextEditingController();
  final Set<String> favorites = {};
  String city = 'الكل', category = 'الكل';
  int tab = 0;
  @override void initState() { super.initState(); loadFavorites(); query.addListener(redraw); }
  void redraw() { if (mounted) setState(() {}); }
  @override void dispose() { query.removeListener(redraw); query.dispose(); super.dispose(); }
  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => favorites.addAll(prefs.getStringList('jawlah_gold_favorites') ?? []));
  }
  Future<void> favorite(Estate e) async {
    setState(() { if (!favorites.add(e.id)) favorites.remove(e.id); });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('jawlah_gold_favorites', favorites.toList());
  }
  List<Estate> get filtered => estates.where((p) =>
    (query.text.trim().isEmpty ||
      (p.title + p.city + p.neighborhood + p.type).contains(query.text.trim())) &&
    (city == 'الكل' || city == p.city) &&
    (category == 'الكل' || category == p.type)).toList();
  void choose(String value) { setState(() { category = value; tab = 1; }); }
  void detail(Estate e) => Navigator.push(context, MaterialPageRoute(
    builder: (_) => EstateDetails(estate: e, isFavorite: favorites.contains(e.id),
      onFavorite: () => favorite(e))));
  void goLogin() => Navigator.push(context,
    MaterialPageRoute(builder: (_) => const PhonePage()));
  Widget sectionTitle(String label, {VoidCallback? action}) =>
    Padding(padding: const EdgeInsets.fromLTRB(17, 22, 17, 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        if (action != null) TextButton(onPressed: action,
          child: const Text('عرض الكل', style: TextStyle(color: kGold))),
      ]));
  Widget notice() => Container(
    margin: const EdgeInsets.fromLTRB(15, 12, 15, 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF302617),
      borderRadius: BorderRadius.circular(13)),
    child: const Row(children: [
      Icon(Icons.info_outline, color: kGold, size: 21),
      SizedBox(width: 10),
      Expanded(child: Text('العقارات والأسعار والصور تجريبية للعرض وليست عروضاً فعلية.',
        style: TextStyle(fontSize: 12, color: kWhite))),
    ]));
  Widget searchField() => Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: TextField(controller: query,
      decoration: InputDecoration(hintText: 'ابحث عن عقارك...',
        prefixIcon: const Icon(Icons.search, color: kWhite),
        suffixIcon: IconButton(onPressed: () => setState(() => tab = 1),
          icon: const Icon(Icons.tune, color: kGold)))));
  Widget categories() => SizedBox(height: 99,
    child: ListView(scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      children: [
        categoryItem('شقق', Icons.apartment),
        categoryItem('فلل', Icons.villa),
        categoryItem('أراضي', Icons.landscape),
      ]));
  Widget categoryItem(String name, IconData icon) => InkWell(
    onTap: () => choose(name),
    child: Container(width: 107, margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: category == name ? const Color(0xFF4C3820) : kSurface,
        border: Border.all(color: category == name ? kGold : kLine),
        borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: kGold, size: 28),
        const SizedBox(height: 7),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      ])));
  Widget hero() => Stack(children: [
    SizedBox(height: 345, width: double.infinity, child: photo(estates.first.image)),
    const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xA7090B0D), Color(0x66090B0D), kBg])))),
    Positioned(top: 17, right: 18, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xAA090B0D),
        borderRadius: BorderRadius.circular(25), border: Border.all(color: kGoldDark)),
      child: const Row(children: [
        Icon(Icons.location_on_outlined, color: kGold, size: 18),
        SizedBox(width: 6),
        Text('المملكة العربية السعودية', style: TextStyle(fontSize: 12)),
      ]))),
    Positioned(left: 15, top: 14, child: IconButton(
      onPressed: () => message(context, 'لا توجد إشعارات حالياً'),
      icon: const Icon(Icons.notifications_none, color: kGold))),
    Positioned(bottom: 15, left: 14, right: 14,
      child: Column(children: [
        brand(size: 27),
        const SizedBox(height: 13),
        const Text('مرحباً بك', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900)),
        const Text('اكتشف أفضل العقارات في المملكة',
          style: TextStyle(color: kMuted, fontSize: 14)),
      ])),
  ]);
  Widget estateCard(Estate e, {bool narrow = false}) => Container(
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 15),
    decoration: BoxDecoration(color: kSurface,
      border: Border.all(color: kLine),
      borderRadius: BorderRadius.circular(19)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: () => detail(e), child: Column(children: [
      Stack(children: [
        SizedBox(height: narrow ? 150 : 198, child: photo(e.image)),
        Positioned(top: 11, right: 10,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(15)),
            child: const Text('مميز ★', style: TextStyle(
              color: kBg, fontWeight: FontWeight.bold, fontSize: 12)))),
        Positioned(top: 8, left: 9,
          child: IconButton.filledTonal(onPressed: () => favorite(e),
            style: IconButton.styleFrom(backgroundColor: const Color(0xCC111315)),
            icon: Icon(favorites.contains(e.id) ? Icons.favorite : Icons.favorite_border,
              color: kGold))),
      ]),
      Padding(padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(e.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19))),
            Text(sar(e.price), style: const TextStyle(
              color: kGold, fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.place_outlined, color: kGold, size: 16),
            Text(e.city + '، ' + e.neighborhood,
              style: const TextStyle(color: kMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 15),
          const Divider(color: kLine, height: 1),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            spec(Icons.square_foot_outlined, e.area.toString() + ' م²'),
            if (e.bedrooms > 0) spec(Icons.bed_outlined, e.bedrooms.toString() + ' غرف'),
            if (e.baths > 0) spec(Icons.bathtub_outlined, e.baths.toString() + ' حمامات'),
          ]),
        ])),
    ])),
  );
  Widget home() => ListView(children: [
    hero(), searchField(), categories(),
    sectionTitle('العقارات المميزة', action: () => setState(() => tab = 1)),
    ...estates.take(3).map((e) => estateCard(e)),
    sectionTitle('عقارات جديدة', action: () => setState(() => tab = 1)),
    ...estates.skip(3).take(2).map((e) => estateCard(e, narrow: true)),
    notice(),
  ]);
  Widget chip(String name, String value, ValueChanged<String> onSelected, List<String> choices) =>
    Container(margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: kSurface,
        border: Border.all(color: kLine), borderRadius: BorderRadius.circular(13)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, dropdownColor: kSurface2, iconEnabledColor: kGold,
        items: choices.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) { if (v != null) onSelected(v); },
      )));
  Widget searchPage() => ListView(children: [
    sectionTitle('ابحث عن عقارك'),
    searchField(),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        Expanded(child: chip('المدينة', city,
          (v) => setState(() => city = v), ['الكل', 'الرياض', 'جدة', 'الدمام'])),
        Expanded(child: chip('النوع', category,
          (v) => setState(() => category = v), ['الكل', 'فلل', 'شقق', 'أراضي'])),
      ])),
    categories(),
    Padding(padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
      child: Text('نتائج البحث — ' + filtered.length.toString() + ' عقار',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
    if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(40),
      child: Center(child: Text('لا توجد عقارات مطابقة للبحث', style: TextStyle(color: kMuted)))),
    ...filtered.map((e) => estateCard(e)),
    notice(),
  ]);
  Widget favoritesPage() {
    final items = estates.where((e) => favorites.contains(e.id)).toList();
    return ListView(children: [
      sectionTitle('المفضلة'),
      const Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, 20),
        child: Text('العقارات التي حفظتها لوقت لاحق',
          style: TextStyle(color: kMuted))),
      if (items.isEmpty) const Padding(padding: EdgeInsets.all(55),
        child: Column(children: [
          Icon(Icons.favorite_border, color: kGold, size: 63),
          SizedBox(height: 20),
          Text('لم تحفظ أي عقار بعد', style: TextStyle(fontSize: 18)),
          SizedBox(height: 7),
          Text('اضغط على القلب لحفظ عقاراتك المفضلة',
            style: TextStyle(color: kMuted)),
        ])),
      ...items.map((e) => estateCard(e)),
      notice(),
    ]);
  }
  Widget notificationsPage() => const Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.notifications_none_rounded, size: 65, color: kGold),
      SizedBox(height: 18),
      Text('الإشعارات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      SizedBox(height: 10),
      Text('لا توجد إشعارات حالياً', style: TextStyle(color: kMuted)),
    ]));
  Widget option(IconData icon, String label, VoidCallback onTap, {bool danger = false}) =>
    Container(margin: const EdgeInsets.fromLTRB(15, 0, 15, 10),
      decoration: BoxDecoration(color: kSurface,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
      child: ListTile(onTap: onTap,
        leading: Icon(icon, color: danger ? Colors.redAccent : kGold),
        title: Text(label, style: TextStyle(color: danger ? Colors.redAccent : kWhite)),
        trailing: const Icon(Icons.chevron_left, color: kMuted)));
  Widget profile() => ListView(children: [
    const SizedBox(height: 27),
    const CircleAvatar(radius: 47, backgroundColor: kSurface2,
      child: Icon(Icons.person_outline, size: 54, color: kGold)),
    const SizedBox(height: 15),
    Text(widget.username == null ? 'مرحباً بك، زائر' : 'مرحباً بك',
      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center),
    if (widget.username != null) Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(widget.username!, textAlign: TextAlign.center,
        style: const TextStyle(color: kMuted))),
    const SizedBox(height: 26),
    Container(margin: const EdgeInsets.all(15), padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF392916), kSurface]),
        border: Border.all(color: kGoldDark),
        borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        const Icon(Icons.workspace_premium_outlined, color: kGold, size: 42),
        const SizedBox(width: 15),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('جولة العقارية', style: TextStyle(
            color: kGold, fontSize: 21, fontWeight: FontWeight.bold)),
          Text('اكتشف العقارات والخدمات في مكان واحد',
            style: TextStyle(color: kMuted, fontSize: 12)),
        ])),
      ])),
    option(Icons.favorite_outline, 'العقارات المحفوظة', () => setState(() => tab = 2)),
    option(Icons.notifications_none, 'الإشعارات', () => setState(() => tab = 3)),
    option(Icons.language, 'الموقع الرسمي', () => site()),
    option(Icons.info_outline, 'عن جولة العقارية', () => showAboutDialog(
      context: context, applicationName: 'جولة العقارية',
      applicationVersion: '0.3.0',
      children: [const Text('نسخة عرض تجريبية بتصميم أسود وذهبي.')])),
    if (widget.username == null)
      option(Icons.login, 'تسجيل الدخول', goLogin)
    else
      option(Icons.logout, 'تسجيل الخروج', () async {
        await AuthApi.logout();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const WelcomePage()), (_) => false);
      }, danger: true),
    notice(),
  ]);
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: IndexedStack(index: tab, children: [
      home(), searchPage(), favoritesPage(), notificationsPage(), profile(),
    ])),
    bottomNavigationBar: NavigationBar(
      backgroundColor: kSurface, indicatorColor: const Color(0xFF40301E),
      selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
      labelTextStyle: WidgetStateProperty.resolveWith((states) =>
        TextStyle(fontSize: 11, color: states.contains(WidgetState.selected) ? kGold : kMuted)),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: kGold), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.search),
          selectedIcon: Icon(Icons.search, color: kGold), label: 'البحث'),
        NavigationDestination(icon: Icon(Icons.favorite_outline),
          selectedIcon: Icon(Icons.favorite, color: kGold), label: 'المفضلة'),
        NavigationDestination(icon: Icon(Icons.notifications_none),
          selectedIcon: Icon(Icons.notifications, color: kGold), label: 'الإشعارات'),
        NavigationDestination(icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: kGold), label: 'حسابي'),
      ],
    ),
  );
}

Widget spec(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
  Icon(icon, color: kGold, size: 20),
  const SizedBox(width: 4),
  Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
]);

class EstateDetails extends StatefulWidget {
  final Estate estate;
  final bool isFavorite;
  final VoidCallback onFavorite;
  const EstateDetails({super.key, required this.estate,
    required this.isFavorite, required this.onFavorite});
  @override State<EstateDetails> createState() => _EstateDetailsState();
}
class _EstateDetailsState extends State<EstateDetails> {
  late bool isFavorite = widget.isFavorite;
  @override Widget build(BuildContext context) {
    final e = widget.estate;
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل العقار'), actions: [
        IconButton(onPressed: () {
          widget.onFavorite(); setState(() => isFavorite = !isFavorite);
        }, icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_outline, color: kGold)),
      ]),
      body: ListView(children: [
        Stack(children: [
          SizedBox(height: 310, child: photo(e.image)),
          Positioned(bottom: 14, right: 16,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xCC111315),
                borderRadius: BorderRadius.circular(14)),
              child: const Text('صورة توضيحية',
                style: TextStyle(color: kWhite, fontSize: 12)))),
        ]),
        Padding(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(e.title, style: const TextStyle(
                fontSize: 27, fontWeight: FontWeight.w900))),
              const Icon(Icons.star, color: kGold),
            ]),
            const SizedBox(height: 9),
            Row(children: [
              const Icon(Icons.place, color: kGold, size: 18),
              Text(e.city + '، ' + e.neighborhood,
                style: const TextStyle(color: kMuted)),
            ]),
            const SizedBox(height: 20),
            Text(sar(e.price), style: const TextStyle(
              color: kGold, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            const Text('سعر توضيحي غير معتمد', style: TextStyle(color: kMuted, fontSize: 12)),
            const SizedBox(height: 24),
            Container(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(color: kSurface,
                border: Border.all(color: kLine),
                borderRadius: BorderRadius.circular(15)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                spec(Icons.square_foot, e.area.toString() + ' م²'),
                if (e.bedrooms > 0) spec(Icons.bed_outlined, e.bedrooms.toString() + ' غرف'),
                if (e.baths > 0) spec(Icons.bathtub_outlined, e.baths.toString() + ' حمامات'),
              ])),
            const SizedBox(height: 28),
            const Text('وصف العقار', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 12),
            Text(e.description, style: const TextStyle(color: kMuted, height: 1.9)),
            const SizedBox(height: 27),
            const Text('مميزات العقار', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              feature(Icons.weekend_outlined, 'مساحات معيشة'),
              feature(Icons.park_outlined, 'تصميم عصري'),
              feature(Icons.home_outlined, 'موقع سكني'),
            ]),
            const SizedBox(height: 29),
            goldButton('تواصل مع جولة', site, icon: Icons.call_outlined),
            const SizedBox(height: 12),
            outlineButton('الموقع الرسمي', site, icon: Icons.open_in_new),
            const SizedBox(height: 20),
            const Text('العقار تجريبي؛ للحجز الفعلي والاستفسار استخدم قنوات جولة الرسمية.',
              style: TextStyle(color: kMuted, fontSize: 12),
              textAlign: TextAlign.center),
          ])),
      ]),
    );
  }
  Widget feature(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(color: kSurface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: kLine)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 19, color: kGold), const SizedBox(width: 8),
      Text(text, style: const TextStyle(color: kMuted, fontSize: 12))
    ]));
}
).hasMatch(pin.text.trim())) { message(context, 'أدخل رمز التحقق المكون من 6 أرقام'); return; }
    setState(() => busy = true);
    try {
      await AuthApi.verifyPhone(widget.phone, pin.text.trim());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
        builder: (_) => JawlahShell(username: widget.phone)), (_) => false);
    } catch (e) {
      if (mounted) message(context, e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('رمز التحقق')),
    body: ListView(padding: const EdgeInsets.all(26), children: [
      const SizedBox(height: 55), brand(size: 33),
      const SizedBox(height: 45),
      const Text('أدخل رمز التحقق', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center),
      const SizedBox(height: 14),
      Text('أرسلنا الرمز إلى ' + widget.phone,
        style: const TextStyle(color: kMuted), textAlign: TextAlign.center),
      const SizedBox(height: 30),
      TextField(controller: pin, maxLength: 6,
        keyboardType: TextInputType.number, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 30, letterSpacing: 12, color: kGold),
        decoration: const InputDecoration(hintText: '••••••', counterText: '')),
      const SizedBox(height: 24),
      goldButton(busy ? 'جارٍ التحقق...' : 'تأكيد', busy ? null : verify),
      TextButton(onPressed: () async {
        try { await AuthApi.sendPhoneCode(widget.phone);
          if (context.mounted) message(context, 'تم طلب رمز جديد');
        } catch (e) { if (context.mounted) message(context,
          e.toString().replaceFirst('Exception: ', '')); }
      }, child: const Text('إعادة إرسال الرمز', style: TextStyle(color: kGold))),
    ]),
  );
}

class JawlahShell extends StatefulWidget {
  final String? username;
  const JawlahShell({super.key, this.username});
  @override State<JawlahShell> createState() => _JawlahShellState();
}
class _JawlahShellState extends State<JawlahShell> {
  final query = TextEditingController();
  final Set<String> favorites = {};
  String city = 'الكل', category = 'الكل';
  int tab = 0;
  @override void initState() { super.initState(); loadFavorites(); query.addListener(redraw); }
  void redraw() { if (mounted) setState(() {}); }
  @override void dispose() { query.removeListener(redraw); query.dispose(); super.dispose(); }
  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => favorites.addAll(prefs.getStringList('jawlah_gold_favorites') ?? []));
  }
  Future<void> favorite(Estate e) async {
    setState(() { if (!favorites.add(e.id)) favorites.remove(e.id); });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('jawlah_gold_favorites', favorites.toList());
  }
  List<Estate> get filtered => estates.where((p) =>
    (query.text.trim().isEmpty ||
      (p.title + p.city + p.neighborhood + p.type).contains(query.text.trim())) &&
    (city == 'الكل' || city == p.city) &&
    (category == 'الكل' || category == p.type)).toList();
  void choose(String value) { setState(() { category = value; tab = 1; }); }
  void detail(Estate e) => Navigator.push(context, MaterialPageRoute(
    builder: (_) => EstateDetails(estate: e, isFavorite: favorites.contains(e.id),
      onFavorite: () => favorite(e))));
  void goLogin() => Navigator.push(context,
    MaterialPageRoute(builder: (_) => const PhonePage()));
  Widget sectionTitle(String label, {VoidCallback? action}) =>
    Padding(padding: const EdgeInsets.fromLTRB(17, 22, 17, 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        if (action != null) TextButton(onPressed: action,
          child: const Text('عرض الكل', style: TextStyle(color: kGold))),
      ]));
  Widget notice() => Container(
    margin: const EdgeInsets.fromLTRB(15, 12, 15, 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF302617),
      borderRadius: BorderRadius.circular(13)),
    child: const Row(children: [
      Icon(Icons.info_outline, color: kGold, size: 21),
      SizedBox(width: 10),
      Expanded(child: Text('العقارات والأسعار والصور تجريبية للعرض وليست عروضاً فعلية.',
        style: TextStyle(fontSize: 12, color: kWhite))),
    ]));
  Widget searchField() => Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: TextField(controller: query,
      decoration: InputDecoration(hintText: 'ابحث عن عقارك...',
        prefixIcon: const Icon(Icons.search, color: kWhite),
        suffixIcon: IconButton(onPressed: () => setState(() => tab = 1),
          icon: const Icon(Icons.tune, color: kGold)))));
  Widget categories() => SizedBox(height: 99,
    child: ListView(scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      children: [
        categoryItem('شقق', Icons.apartment),
        categoryItem('فلل', Icons.villa),
        categoryItem('أراضي', Icons.landscape),
      ]));
  Widget categoryItem(String name, IconData icon) => InkWell(
    onTap: () => choose(name),
    child: Container(width: 107, margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: category == name ? const Color(0xFF4C3820) : kSurface,
        border: Border.all(color: category == name ? kGold : kLine),
        borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: kGold, size: 28),
        const SizedBox(height: 7),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      ])));
  Widget hero() => Stack(children: [
    SizedBox(height: 345, width: double.infinity, child: photo(estates.first.image)),
    const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xA7090B0D), Color(0x66090B0D), kBg])))),
    Positioned(top: 17, right: 18, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xAA090B0D),
        borderRadius: BorderRadius.circular(25), border: Border.all(color: kGoldDark)),
      child: const Row(children: [
        Icon(Icons.location_on_outlined, color: kGold, size: 18),
        SizedBox(width: 6),
        Text('المملكة العربية السعودية', style: TextStyle(fontSize: 12)),
      ]))),
    Positioned(left: 15, top: 14, child: IconButton(
      onPressed: () => message(context, 'لا توجد إشعارات حالياً'),
      icon: const Icon(Icons.notifications_none, color: kGold))),
    Positioned(bottom: 15, left: 14, right: 14,
      child: Column(children: [
        brand(size: 27),
        const SizedBox(height: 13),
        const Text('مرحباً بك', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900)),
        const Text('اكتشف أفضل العقارات في المملكة',
          style: TextStyle(color: kMuted, fontSize: 14)),
      ])),
  ]);
  Widget estateCard(Estate e, {bool narrow = false}) => Container(
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 15),
    decoration: BoxDecoration(color: kSurface,
      border: Border.all(color: kLine),
      borderRadius: BorderRadius.circular(19)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: () => detail(e), child: Column(children: [
      Stack(children: [
        SizedBox(height: narrow ? 150 : 198, child: photo(e.image)),
        Positioned(top: 11, right: 10,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(15)),
            child: const Text('مميز ★', style: TextStyle(
              color: kBg, fontWeight: FontWeight.bold, fontSize: 12)))),
        Positioned(top: 8, left: 9,
          child: IconButton.filledTonal(onPressed: () => favorite(e),
            style: IconButton.styleFrom(backgroundColor: const Color(0xCC111315)),
            icon: Icon(favorites.contains(e.id) ? Icons.favorite : Icons.favorite_border,
              color: kGold))),
      ]),
      Padding(padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(e.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19))),
            Text(sar(e.price), style: const TextStyle(
              color: kGold, fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.place_outlined, color: kGold, size: 16),
            Text(e.city + '، ' + e.neighborhood,
              style: const TextStyle(color: kMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 15),
          const Divider(color: kLine, height: 1),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            spec(Icons.square_foot_outlined, e.area.toString() + ' م²'),
            if (e.bedrooms > 0) spec(Icons.bed_outlined, e.bedrooms.toString() + ' غرف'),
            if (e.baths > 0) spec(Icons.bathtub_outlined, e.baths.toString() + ' حمامات'),
          ]),
        ])),
    ])),
  );
  Widget home() => ListView(children: [
    hero(), searchField(), categories(),
    sectionTitle('العقارات المميزة', action: () => setState(() => tab = 1)),
    ...estates.take(3).map((e) => estateCard(e)),
    sectionTitle('عقارات جديدة', action: () => setState(() => tab = 1)),
    ...estates.skip(3).take(2).map((e) => estateCard(e, narrow: true)),
    notice(),
  ]);
  Widget chip(String name, String value, ValueChanged<String> onSelected, List<String> choices) =>
    Container(margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: kSurface,
        border: Border.all(color: kLine), borderRadius: BorderRadius.circular(13)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, dropdownColor: kSurface2, iconEnabledColor: kGold,
        items: choices.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) { if (v != null) onSelected(v); },
      )));
  Widget searchPage() => ListView(children: [
    sectionTitle('ابحث عن عقارك'),
    searchField(),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        Expanded(child: chip('المدينة', city,
          (v) => setState(() => city = v), ['الكل', 'الرياض', 'جدة', 'الدمام'])),
        Expanded(child: chip('النوع', category,
          (v) => setState(() => category = v), ['الكل', 'فلل', 'شقق', 'أراضي'])),
      ])),
    categories(),
    Padding(padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
      child: Text('نتائج البحث — ' + filtered.length.toString() + ' عقار',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
    if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(40),
      child: Center(child: Text('لا توجد عقارات مطابقة للبحث', style: TextStyle(color: kMuted)))),
    ...filtered.map((e) => estateCard(e)),
    notice(),
  ]);
  Widget favoritesPage() {
    final items = estates.where((e) => favorites.contains(e.id)).toList();
    return ListView(children: [
      sectionTitle('المفضلة'),
      const Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, 20),
        child: Text('العقارات التي حفظتها لوقت لاحق',
          style: TextStyle(color: kMuted))),
      if (items.isEmpty) const Padding(padding: EdgeInsets.all(55),
        child: Column(children: [
          Icon(Icons.favorite_border, color: kGold, size: 63),
          SizedBox(height: 20),
          Text('لم تحفظ أي عقار بعد', style: TextStyle(fontSize: 18)),
          SizedBox(height: 7),
          Text('اضغط على القلب لحفظ عقاراتك المفضلة',
            style: TextStyle(color: kMuted)),
        ])),
      ...items.map((e) => estateCard(e)),
      notice(),
    ]);
  }
  Widget notificationsPage() => const Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.notifications_none_rounded, size: 65, color: kGold),
      SizedBox(height: 18),
      Text('الإشعارات', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      SizedBox(height: 10),
      Text('لا توجد إشعارات حالياً', style: TextStyle(color: kMuted)),
    ]));
  Widget option(IconData icon, String label, VoidCallback onTap, {bool danger = false}) =>
    Container(margin: const EdgeInsets.fromLTRB(15, 0, 15, 10),
      decoration: BoxDecoration(color: kSurface,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
      child: ListTile(onTap: onTap,
        leading: Icon(icon, color: danger ? Colors.redAccent : kGold),
        title: Text(label, style: TextStyle(color: danger ? Colors.redAccent : kWhite)),
        trailing: const Icon(Icons.chevron_left, color: kMuted)));
  Widget profile() => ListView(children: [
    const SizedBox(height: 27),
    const CircleAvatar(radius: 47, backgroundColor: kSurface2,
      child: Icon(Icons.person_outline, size: 54, color: kGold)),
    const SizedBox(height: 15),
    Text(widget.username == null ? 'مرحباً بك، زائر' : 'مرحباً بك',
      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center),
    if (widget.username != null) Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(widget.username!, textAlign: TextAlign.center,
        style: const TextStyle(color: kMuted))),
    const SizedBox(height: 26),
    Container(margin: const EdgeInsets.all(15), padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF392916), kSurface]),
        border: Border.all(color: kGoldDark),
        borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        const Icon(Icons.workspace_premium_outlined, color: kGold, size: 42),
        const SizedBox(width: 15),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('جولة العقارية', style: TextStyle(
            color: kGold, fontSize: 21, fontWeight: FontWeight.bold)),
          Text('اكتشف العقارات والخدمات في مكان واحد',
            style: TextStyle(color: kMuted, fontSize: 12)),
        ])),
      ])),
    option(Icons.favorite_outline, 'العقارات المحفوظة', () => setState(() => tab = 2)),
    option(Icons.notifications_none, 'الإشعارات', () => setState(() => tab = 3)),
    option(Icons.language, 'الموقع الرسمي', () => site()),
    option(Icons.info_outline, 'عن جولة العقارية', () => showAboutDialog(
      context: context, applicationName: 'جولة العقارية',
      applicationVersion: '0.2.0',
      children: [const Text('نسخة عرض تجريبية بتصميم أسود وذهبي.')])),
    if (widget.username == null)
      option(Icons.login, 'تسجيل الدخول', goLogin)
    else
      option(Icons.logout, 'تسجيل الخروج', () =>
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const WelcomePage()), (_) => false),
        danger: true),
    notice(),
  ]);
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: IndexedStack(index: tab, children: [
      home(), searchPage(), favoritesPage(), notificationsPage(), profile(),
    ])),
    bottomNavigationBar: NavigationBar(
      backgroundColor: kSurface, indicatorColor: const Color(0xFF40301E),
      selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
      labelTextStyle: WidgetStateProperty.resolveWith((states) =>
        TextStyle(fontSize: 11, color: states.contains(WidgetState.selected) ? kGold : kMuted)),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: kGold), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.search),
          selectedIcon: Icon(Icons.search, color: kGold), label: 'البحث'),
        NavigationDestination(icon: Icon(Icons.favorite_outline),
          selectedIcon: Icon(Icons.favorite, color: kGold), label: 'المفضلة'),
        NavigationDestination(icon: Icon(Icons.notifications_none),
          selectedIcon: Icon(Icons.notifications, color: kGold), label: 'الإشعارات'),
        NavigationDestination(icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: kGold), label: 'حسابي'),
      ],
    ),
  );
}

Widget spec(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
  Icon(icon, color: kGold, size: 20),
  const SizedBox(width: 4),
  Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
]);

class EstateDetails extends StatefulWidget {
  final Estate estate;
  final bool isFavorite;
  final VoidCallback onFavorite;
  const EstateDetails({super.key, required this.estate,
    required this.isFavorite, required this.onFavorite});
  @override State<EstateDetails> createState() => _EstateDetailsState();
}
class _EstateDetailsState extends State<EstateDetails> {
  late bool isFavorite = widget.isFavorite;
  @override Widget build(BuildContext context) {
    final e = widget.estate;
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل العقار'), actions: [
        IconButton(onPressed: () {
          widget.onFavorite(); setState(() => isFavorite = !isFavorite);
        }, icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_outline, color: kGold)),
      ]),
      body: ListView(children: [
        Stack(children: [
          SizedBox(height: 310, child: photo(e.image)),
          Positioned(bottom: 14, right: 16,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xCC111315),
                borderRadius: BorderRadius.circular(14)),
              child: const Text('صورة توضيحية',
                style: TextStyle(color: kWhite, fontSize: 12)))),
        ]),
        Padding(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(e.title, style: const TextStyle(
                fontSize: 27, fontWeight: FontWeight.w900))),
              const Icon(Icons.star, color: kGold),
            ]),
            const SizedBox(height: 9),
            Row(children: [
              const Icon(Icons.place, color: kGold, size: 18),
              Text(e.city + '، ' + e.neighborhood,
                style: const TextStyle(color: kMuted)),
            ]),
            const SizedBox(height: 20),
            Text(sar(e.price), style: const TextStyle(
              color: kGold, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            const Text('سعر توضيحي غير معتمد', style: TextStyle(color: kMuted, fontSize: 12)),
            const SizedBox(height: 24),
            Container(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(color: kSurface,
                border: Border.all(color: kLine),
                borderRadius: BorderRadius.circular(15)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                spec(Icons.square_foot, e.area.toString() + ' م²'),
                if (e.bedrooms > 0) spec(Icons.bed_outlined, e.bedrooms.toString() + ' غرف'),
                if (e.baths > 0) spec(Icons.bathtub_outlined, e.baths.toString() + ' حمامات'),
              ])),
            const SizedBox(height: 28),
            const Text('وصف العقار', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 12),
            Text(e.description, style: const TextStyle(color: kMuted, height: 1.9)),
            const SizedBox(height: 27),
            const Text('مميزات العقار', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              feature(Icons.weekend_outlined, 'مساحات معيشة'),
              feature(Icons.park_outlined, 'تصميم عصري'),
              feature(Icons.home_outlined, 'موقع سكني'),
            ]),
            const SizedBox(height: 29),
            goldButton('تواصل مع جولة', site, icon: Icons.call_outlined),
            const SizedBox(height: 12),
            outlineButton('الموقع الرسمي', site, icon: Icons.open_in_new),
            const SizedBox(height: 20),
            const Text('العقار تجريبي؛ للحجز الفعلي والاستفسار استخدم قنوات جولة الرسمية.',
              style: TextStyle(color: kMuted, fontSize: 12),
              textAlign: TextAlign.center),
          ])),
      ]),
    );
  }
  Widget feature(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(color: kSurface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: kLine)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 19, color: kGold), const SizedBox(width: 8),
      Text(text, style: const TextStyle(color: kMuted, fontSize: 12))
    ]));
}

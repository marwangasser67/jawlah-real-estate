
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Public, read-only catalog comes from approved Jawlah admin properties.
// Viewing requests and owner previews remain local drafts.
const uiBg = Color(0xFF0B0D10);
const uiPanel = Color(0xFF191B20);
const uiRaised = Color(0xFF27282D);
const uiGold = Color(0xFFE0BC7C);
const uiGoldDim = Color(0xFF9C7B4C);
const uiWhite = Color(0xFFF9F6F1);
const uiMuted = Color(0xFFB6B5B3);
const uiLine = Color(0xFF3A3B40);

const kJawlahCatalog = 'https://jawlah-real-estate-5sz9.hatchable.site/api/catalog';
const kHeroPhoto =
  'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=1000&q=85';

class HomeInfo {
  final String id, title, city, areaName, type, photo, description;
  final int price, sqm, beds, baths;
  final List<String> gallery;
  const HomeInfo(
    this.id, this.title, this.city, this.areaName,
    this.type, this.photo, this.price, this.sqm, this.beds, this.baths,
    {this.description = '', this.gallery = const []});

  factory HomeInfo.fromCatalog(Map<String, dynamic> data) {
    final raw = data['images'];
    final photos = raw is List
      ? raw.whereType<String>().where((s) => s.startsWith('https://')).toList()
      : <String>[];
    int integer(String field) =>
      (num.tryParse((data[field] ?? 0).toString()) ?? 0).round();
    String field(String key) => (data[key] ?? '').toString();
    return HomeInfo(
      field('id'), field('title'), field('city'), field('district'),
      field('property_type'), photos.isEmpty ? '' : photos.first,
      integer('price_sar'), integer('area_sqm'),
      integer('bedrooms'), integer('bathrooms'),
      description: field('description'), gallery: photos,
    );
  }
}
String comma(int number) => number.toString()
  .replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',');

Widget propertyPicture(String url, {double? height}) => Image.network(
  url, fit: BoxFit.cover, width: double.infinity, height: height,
  loadingBuilder: (context, child, progress) =>
    progress == null ? child : Container(
      height: height, color: uiRaised, alignment: Alignment.center,
      child: const Icon(Icons.apartment_rounded, size: 55, color: uiGold)),
  errorBuilder: (context, error, stackTrace) => Container(
    height: height, width: double.infinity,
    decoration: const BoxDecoration(gradient: LinearGradient(
      colors: [Color(0xFF4B3824), uiPanel])),
    child: const Center(child: Icon(Icons.villa_outlined, size: 60, color: uiGold))),
);
Widget jawlahLogo(double size) => Image.asset(
  'assets/branding/jawlah_launcher.png', width: size, height: size, fit: BoxFit.contain);

Widget goldAction(String text, VoidCallback? onTap, {IconData icon = Icons.arrow_back}) =>
  SizedBox(width: double.infinity, height: 51,
    child: FilledButton.icon(onPressed: onTap,
      icon: Icon(icon, size: 19), label: Text(text, maxLines: 1,
        overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        backgroundColor: uiGold, foregroundColor: uiBg,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))));

Widget outlineAction(String text, VoidCallback onTap, {IconData icon = Icons.add}) =>
  SizedBox(width: double.infinity, height: 48,
    child: OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 19),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        foregroundColor: uiGold, side: const BorderSide(color: uiGoldDim),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))));

Widget sampleBanner() => Container(
  margin: const EdgeInsets.only(top: 12, bottom: 15),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(color: const Color(0xFF302619),
    border: Border.all(color: const Color(0xFF5A4429)),
    borderRadius: BorderRadius.circular(13)),
  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(Icons.info_outline, color: uiGold, size: 18),
    SizedBox(width: 8),
    Expanded(child: Text('العقارات المعروضة منشورة من لوحة جولة العقارية. طلبات المعاينة تُحفظ على الجهاز ولا تُرسل للشركة تلقائيًا.',
      style: TextStyle(color: uiGold, fontSize: 11, height: 1.5))),
  ]));

class LuxuryShell extends StatefulWidget {
  final String? username;
  final void Function(BuildContext) onLogin;
  final Future<void> Function(BuildContext) onLogout;
  const LuxuryShell({super.key, this.username,
    required this.onLogin, required this.onLogout});
  @override
  State<LuxuryShell> createState() => _LuxuryShellState();
}

class _LuxuryShellState extends State<LuxuryShell> with WidgetsBindingObserver {
  final query = TextEditingController();
  final Set<String> saved = {}, compared = {};
  final List<String> viewed = [], viewings = [];
  List<HomeInfo> places = [];
  bool isCatalogLoading = true;
  String? catalogError;
  DateTime? lastCatalogRefresh;
  int tab = 0, maximum = 0, minBeds = 0, minArea = 0;
  String city = 'الكل', category = 'الكل', sort = 'المميزة';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    refreshCatalog();
    query.addListener(_changed);
  }
  void _changed() { if (mounted) setState(() {}); }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    query.removeListener(_changed);
    query.dispose();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshCatalog(force: false);
  }
  Future<void> refreshCatalog({bool force = true}) async {
    if (isCatalogLoading && lastCatalogRefresh != null) return;
    if (!force && lastCatalogRefresh != null &&
        DateTime.now().difference(lastCatalogRefresh!) < const Duration(seconds: 30)) {
      return;
    }
    lastCatalogRefresh = DateTime.now();
    if (mounted) setState(() => isCatalogLoading = true);
    try {
      final response = await http.get(Uri.parse(kJawlahCatalog),
        headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 18));
      final mime = response.headers['content-type'] ?? '';
      if (response.statusCode != 200 || !mime.contains('application/json')) {
        throw const FormatException('كتالوج العقارات غير متاح. تأكد من صلاحيات عرض الكتالوج.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['properties'] is! List) {
        throw const FormatException('بيانات الكتالوج غير متوقعة.');
      }
      final updated = (decoded['properties'] as List)
        .whereType<Map<String, dynamic>>()
        .map(HomeInfo.fromCatalog)
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        places = updated;
        isCatalogLoading = false;
        catalogError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isCatalogLoading = false;
        catalogError = 'تعذر تحميل العقارات. تحقق من الإنترنت وإعدادات إتاحة الكتالوج، ثم أعد المحاولة.';
      });
    }
  }

  Widget catalogFeedback() {
    if (isCatalogLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: uiGold)));
    }
    if (catalogError != null) {
      return Container(
        padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(color: uiPanel,
          border: Border.all(color: uiGoldDim),
          borderRadius: BorderRadius.circular(13)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تعذر تحديث العقارات',
            style: TextStyle(color: uiGold, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(catalogError!, style: const TextStyle(color: uiMuted, fontSize: 12)),
          const SizedBox(height: 10),
          outlineAction('إعادة المحاولة', () => refreshCatalog(), icon: Icons.refresh),
        ]));
    }
    if (places.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(children: [
          const Icon(Icons.home_work_outlined, size: 43, color: uiGold),
          const SizedBox(height: 9),
          const Text('لا توجد عقارات منشورة حالياً',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('العقارات تظهر بعد اختيار «جاهز للعرض» من لوحة تحكم جولة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: uiMuted, fontSize: 12)),
          const SizedBox(height: 10),
          outlineAction('تحديث العقارات', () => refreshCatalog(), icon: Icons.refresh),
        ]));
    }
    return const SizedBox.shrink();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      saved.addAll(p.getStringList('v4_saved') ?? []);
      compared.addAll(p.getStringList('v4_compare') ?? []);
      viewed.addAll(p.getStringList('v4_history') ?? []);
      viewings.addAll(p.getStringList('v4_drafts') ?? []);
    });
  }
  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('v4_saved', saved.toList());
    await p.setStringList('v4_compare', compared.toList());
    await p.setStringList('v4_history', viewed);
    await p.setStringList('v4_drafts', viewings);
  }
  void toast(String t) { if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), backgroundColor: uiRaised,
        behavior: SnackBarBehavior.floating)); }
  void setSaved(HomeInfo h) { setState(() {
      saved.contains(h.id) ? saved.remove(h.id) : saved.add(h.id);
    }); _persist(); }
  void setCompare(HomeInfo h) {
    if (!compared.contains(h.id) && compared.length >= 3) {
      toast('تقدر تقارن 3 عقارات بحد أقصى'); return;
    }
    setState(() {
      compared.contains(h.id) ? compared.remove(h.id) : compared.add(h.id);
    }); _persist();
  }
  void see(HomeInfo h) {
    setState(() { viewed.remove(h.id); viewed.insert(0,h.id);
      if (viewed.length > 7) viewed.removeLast(); });
    _persist();
    Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyPage(
      property: h, isSaved: () => saved.contains(h.id),
      isCompared: () => compared.contains(h.id),
      flipSaved: () => setSaved(h), flipCompare: () => setCompare(h),
      onRequest: () => request(h))));
  }
  void request(HomeInfo h) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ViewingPage(
      property: h, onSave: (date) {
        setState(() => viewings.insert(0,h.id + '|' + date.toIso8601String().substring(0,10)));
        _persist();
      })));
  }
  void goBrowse([String? kind]) => setState(() {
    tab = 1; if (kind != null) category = kind;
  });
  Future<void> website() async {
    final url = Uri.parse('https://www.jawlahre.sa');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      toast('تعذّر فتح الموقع الرسمي');
    }
  }
  List<HomeInfo> get results {
    final term = query.text.trim().toLowerCase();
    final list = places.where((h) =>
      (term.isEmpty ||
        (h.title + h.city + h.areaName + h.type).toLowerCase().contains(term)) &&
      (city == 'الكل' || city == h.city) &&
      (category == 'الكل' || category == h.type) &&
      (maximum == 0 || h.price <= maximum) && h.beds >= minBeds && h.sqm >= minArea).toList();
    if (sort == 'السعر الأقل') { list.sort((a,b) => a.price.compareTo(b.price)); }
    if (sort == 'السعر الأعلى') { list.sort((a,b) => b.price.compareTo(a.price)); }
    if (sort == 'المساحة الأكبر') { list.sort((a,b) => b.sqm.compareTo(a.sqm)); }
    return list;
  }
  Widget headline(String title, {String? hint, VoidCallback? more}) =>
    Padding(padding: const EdgeInsets.only(top: 23, bottom: 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(
            color: uiWhite, fontSize: 21, fontWeight: FontWeight.w900))),
          if (more != null) TextButton(onPressed: more,
            child: const Text('عرض الكل', style: TextStyle(color: uiGold))),
        ]),
        if (hint != null) Text(hint, style: const TextStyle(
          color: uiMuted, fontSize: 12)),
      ]));
  Widget smallDetail(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: uiGoldDim),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(color: uiMuted, fontSize: 11)),
    ]);
  Widget propertyTile(HomeInfo h) => Container(
    margin: const EdgeInsets.only(bottom: 15),
    decoration: BoxDecoration(color: uiPanel,
      border: Border.all(color: uiLine),
      borderRadius: BorderRadius.circular(20)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: () => see(h), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          SizedBox(height: 190, width: double.infinity,
            child: propertyPicture(h.photo)),
          Positioned(top: 13, right: 13, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xE3191B20),
              borderRadius: BorderRadius.circular(30)),
            child: Text(h.type, style: const TextStyle(
              color: uiGold, fontSize: 12, fontWeight: FontWeight.bold)))),
          Positioned(top: 4, left: 3,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'المفضلة', onPressed: () => setSaved(h),
                style: IconButton.styleFrom(backgroundColor: const Color(0xDD17191E)),
                icon: Icon(saved.contains(h.id)
                  ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: uiGold)),
              IconButton(tooltip: 'قارن', onPressed: () => setCompare(h),
                style: IconButton.styleFrom(backgroundColor: const Color(0xDD17191E)),
                icon: Icon(compared.contains(h.id)
                  ? Icons.check_box_rounded : Icons.compare_arrows_rounded,
                  color: uiGold)),
            ])),
        ]),
        Padding(padding: const EdgeInsets.all(15), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          smallDetail(Icons.location_on_outlined,h.city + ' • ' + h.areaName),
          const SizedBox(height: 13),
          Row(children: [
            Expanded(child: Text(comma(h.price) + ' ر.س',
              style: const TextStyle(color: uiGold,
                fontSize: 18, fontWeight: FontWeight.w900),
              overflow: TextOverflow.ellipsis)),
            Text(h.sqm.toString() + ' م²', style: const TextStyle(
              color: uiWhite, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          const Divider(color: uiLine, height: 1),
          const SizedBox(height: 12),
          Wrap(spacing: 17, runSpacing: 9, children: [
            smallDetail(Icons.square_foot_outlined,h.sqm.toString()+' م²'),
            if(h.beds>0) smallDetail(Icons.bed_outlined,h.beds.toString()+' غرف'),
            if(h.baths>0) smallDetail(Icons.bathtub_outlined,h.baths.toString()+' حمام'),
          ]),
        ])),
      ])));
  Widget quickCard(String label, IconData icon) => Expanded(
    child: InkWell(onTap: () => goBrowse(label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 19),
        decoration: BoxDecoration(color: uiPanel,
          border: Border.all(color: uiLine),
          borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(icon, color: uiGold, size: 29),
          const SizedBox(height: 9),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]))));
  Widget serviceCard(String title,String explanation, IconData icon, VoidCallback go) =>
    Padding(padding: const EdgeInsets.only(bottom: 11),
      child: InkWell(onTap: go, borderRadius: BorderRadius.circular(15),
        child: Container(padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: uiPanel,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: uiLine)),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFF43331F),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: uiGold)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(explanation, style: const TextStyle(
                  color: uiMuted, fontSize: 11)),
              ])),
            const Icon(Icons.chevron_left, color: uiGold),
          ]))));
  Widget home() => ListView(
    key: const PageStorageKey('v4-home'),
    padding: const EdgeInsets.fromLTRB(15, 9, 15, 30), children: [
    Row(children: [
      Container(width: 58, height: 58, padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: uiPanel,
          border: Border.all(color: uiGoldDim),
          borderRadius: BorderRadius.circular(16)),
        child: jawlahLogo(48)),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('جولة العقارية', style: TextStyle(
            fontSize: 21, fontWeight: FontWeight.w900)),
          Text('مساحتك تبدأ من هنا', style: TextStyle(
            color: uiGold, fontSize: 12)),
        ])),
      IconButton(onPressed: () => setState(() => tab = 3),
        icon: const Icon(Icons.favorite_border, color: uiGold)),
    ]),
    const SizedBox(height: 15),
    Container(height: 265, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
        border: Border.all(color: uiGoldDim)),
      child: Stack(fit: StackFit.expand, children: [
        propertyPicture(places.isEmpty ? kHeroPhoto : places.first.photo),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0x22000000), Color(0xC70A0B0E), uiBg]))),
        Positioned(top: 15,right: 15,child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12,vertical: 7),
          decoration: BoxDecoration(color: const Color(0xE7191B20),
            borderRadius: BorderRadius.circular(20)),
          child: const Text('تجربة عقارية فاخرة',style: TextStyle(
            color: uiGold,fontSize: 12,fontWeight: FontWeight.bold)))),
        Positioned(bottom: 18,right: 18,left: 18,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('اكتشف بيت أحلامك',style: TextStyle(
              fontSize: 28,fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('فلل، شقق، وأراضٍ بخيارات تساعدك في البحث',
              style: TextStyle(color: uiWhite,fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(width: 165,height: 42,
              child: FilledButton(onPressed: () => goBrowse(),
                style: FilledButton.styleFrom(
                  backgroundColor: uiGold, foregroundColor: uiBg),
                child: const Text('استكشف العقارات',
                  style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold)))),
          ])),
      ])),
    catalogFeedback(),
    headline('بحث حسب نوع العقار',hint:'اختار اللي يناسبك'),
    Row(children: [
      quickCard('فيلا',Icons.villa_outlined),
      quickCard('شقة',Icons.apartment_rounded),
      quickCard('أرض',Icons.landscape_outlined),
    ]),
    headline('مشاريع جولة المنشورة',hint:'عقارات حقيقية تتحدث من لوحة الإدارة',more:()=>goBrowse()),
    ...places.take(2).map(propertyTile),
    headline('أدوات عقارية',hint:'خدمات عملية تقدر تجربها'),
    serviceCard('قارن بين العقارات','السعر والمساحة والغرف جنباً إلى جنب',
      Icons.compare_arrows_rounded,()=>setState(()=>tab=2)),
    serviceCard('حاسبة التمويل','احسب القسط الشهري تقريبياً',
      Icons.calculate_outlined,openMortgage),
    serviceCard('اطلب معاينة','احفظ موعداً مبدئياً على جهازك',
      Icons.event_outlined,()=>places.isEmpty ? goBrowse() : request(places.first)),
    headline('اكتشف المزيد',more:()=>goBrowse()),
    ...places.skip(2).take(2).map(propertyTile),
  ]);
  Widget searchPage() => ListView(
    key: const PageStorageKey('v4-search'),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 25), children: [
      const Text('ابحث عن عقارك',style: TextStyle(
        fontSize: 27,fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      const Text('بحث سريع وفلاتر تناسب احتياجاتك',
        style: TextStyle(color: uiMuted,fontSize: 13)),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: () => refreshCatalog(),
          icon: const Icon(Icons.refresh, size: 19),
          label: const Text('تحديث من لوحة الإدارة'),
          style: TextButton.styleFrom(foregroundColor: uiGold))),
      const SizedBox(height: 8),
      TextField(controller: query,
        decoration: InputDecoration(
          hintText:'المدينة، الحي، نوع العقار',
          prefixIcon: const Icon(Icons.search,color: uiGold),
          suffixIcon: IconButton(onPressed: filters,
            icon: const Icon(Icons.tune,color: uiGold)),
          filled: true,fillColor: uiPanel,
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(17)))),
      const SizedBox(height: 11),
      SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: Row(children: [
          for(final c in ['الكل','الرياض','جدة','الدمام','الخبر'])
            _choice(c,city,()=>setState(()=>city=c)),
        ])),
      SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: Row(children: [
          for(final c in ['الكل','فيلا','شقة','أرض'])
            _choice(c,category,()=>setState(()=>category=c)),
        ])),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Text(results.length.toString()+' نتائج تجريبية',
          style: const TextStyle(fontSize: 17,fontWeight: FontWeight.bold))),
        TextButton.icon(onPressed: filters,
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('فلاتر متقدمة'),
          style: TextButton.styleFrom(foregroundColor: uiGold)),
      ]),
      if (places.isEmpty || catalogError != null || isCatalogLoading) catalogFeedback(),
      if (places.isNotEmpty && results.isEmpty) empty(Icons.search_off,'مفيش نتائج مناسبة',
        'جرّب تغيّر المدينة أو السعر','مسح الفلاتر',clearFilters),
      ...results.map(propertyTile),
    ]);
  Widget _choice(String label,String selected,VoidCallback tap) =>
    Padding(padding:const EdgeInsets.only(left:7),child:
      ChoiceChip(label:Text(label),selected:label==selected,
        showCheckmark:false,
        selectedColor:uiGold,backgroundColor:uiPanel,
        labelStyle:TextStyle(color:label==selected?uiBg:uiWhite,fontSize:12),
        side:BorderSide(color:label==selected?uiGold:uiLine),
        onSelected:(_)=>tap()));
  void clearFilters()=>setState(() {
    city='الكل';category='الكل';sort='المميزة';
    maximum=0;minBeds=0;minArea=0;query.clear();
  });
  void filters() {
    String c=city,t=category,o=sort;
    int p=maximum,b=minBeds,a=minArea;
    showModalBottomSheet<void>(context:context,isScrollControlled:true,
      useSafeArea:true,backgroundColor:uiPanel,
      shape:const RoundedRectangleBorder(
        borderRadius:BorderRadius.vertical(top:Radius.circular(23))),
      builder:(sheet)=>StatefulBuilder(builder:(ctx,change)=>
        Padding(padding:const EdgeInsets.all(19),
          child:SingleChildScrollView(child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                const Expanded(child:Text('فلاتر البحث المتقدمة',
                  style:TextStyle(fontSize:22,fontWeight:FontWeight.bold))),
                IconButton(onPressed:()=>Navigator.pop(sheet),
                  icon:const Icon(Icons.close,color:uiMuted)),
              ]),
              const SizedBox(height:13),
              const Text('المدينة',style:TextStyle(fontWeight:FontWeight.bold)),
              Wrap(spacing:6,children:[
                for(final v in ['الكل','الرياض','جدة','الدمام','الخبر'])
                  _choice(v,c,()=>change(()=>c=v)),
              ]),
              const SizedBox(height:13),
              const Text('نوع العقار',style:TextStyle(fontWeight:FontWeight.bold)),
              Wrap(spacing:6,children:[
                for(final v in ['الكل','فيلا','شقة','أرض'])
                  _choice(v,t,()=>change(()=>t=v)),
              ]),
              const SizedBox(height:14),
              Text('السعر الأقصى: '+comma(p)+' ر.س'),
              Slider(value:p.toDouble(),min:1000000,max:6000000,
                divisions:20,activeColor:uiGold,
                onChanged:(v)=>change(()=>p=v.round())),
              Text('غرف النوم على الأقل: '+b.toString()),
              Slider(value:b.toDouble(),min:0,max:6,divisions:6,
                activeColor:uiGold,onChanged:(v)=>change(()=>b=v.round())),
              Text('المساحة على الأقل: '+a.toString()+' م²'),
              Slider(value:a.toDouble(),min:0,max:600,divisions:12,
                activeColor:uiGold,onChanged:(v)=>change(()=>a=v.round())),
              const SizedBox(height:10),
              DropdownButtonFormField<String>(
                initialValue:o,dropdownColor:uiRaised,
                decoration:const InputDecoration(labelText:'ترتيب النتائج'),
                items:['المميزة','السعر الأقل','السعر الأعلى','المساحة الأكبر']
                  .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
                onChanged:(v){if(v!=null)change(()=>o=v);}),
              const SizedBox(height:23),
              goldAction('عرض النتائج',(){
                setState(() {
                  city=c;category=t;sort=o;maximum=p;minBeds=b;minArea=a;tab=1;
                });
                Navigator.pop(sheet);
              },icon:Icons.check),
              Center(child:TextButton(onPressed:(){
                Navigator.pop(sheet);clearFilters();
              },child:const Text('إعادة الضبط',
                style:TextStyle(color:uiGold)))),
            ])))));
  }
  Widget empty(IconData icon,String title,String info,
      String action,VoidCallback go)=>Padding(
    padding:const EdgeInsets.symmetric(horizontal:16,vertical:45),
    child:Column(children:[
      Icon(icon,size:67,color:uiGold),
      const SizedBox(height:15),
      Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      Text(info,textAlign:TextAlign.center,style:const TextStyle(
        color:uiMuted,height:1.6)),
      const SizedBox(height:23),
      goldAction(action,go),
    ]));
  Widget comparePage() {
    final items=places.where((e)=>compared.contains(e.id)).toList();
    return ListView(padding:const EdgeInsets.fromLTRB(15,15,15,25),children:[
      const Text('مقارنة العقارات',style:TextStyle(
        fontSize:27,fontWeight:FontWeight.w900)),
      const SizedBox(height:9),
      Text(items.length.toString()+' / 3 عقارات مختارة',
        style:const TextStyle(color:uiMuted)),
      const SizedBox(height:15),
      if(items.isEmpty) empty(Icons.compare_arrows,'قارن العقارات بسهولة',
        'اضغط على زر المقارنة في كارت العقار لاختيار عقارين أو ثلاثة.',
        'استكشف العقارات',()=>goBrowse())
      else ...[
        SizedBox(height:170,child:Row(children:[
          for(final e in items) Expanded(child:Container(
            margin:const EdgeInsets.only(left:5),
            clipBehavior:Clip.antiAlias,
            decoration:BoxDecoration(borderRadius:BorderRadius.circular(13)),
            child:Stack(fit:StackFit.expand,children:[
              propertyPicture(e.photo),
              const DecoratedBox(decoration:BoxDecoration(
                gradient:LinearGradient(begin:Alignment.topCenter,
                  end:Alignment.bottomCenter,
                  colors:[Colors.transparent,Color(0xEF0B0D10)]))),
              Positioned(top:3,left:3,child:IconButton(
                onPressed:()=>setCompare(e),
                style:IconButton.styleFrom(backgroundColor:uiBg),
                icon:const Icon(Icons.close,color:uiGold,size:19))),
              Positioned(right:8,bottom:8,left:8,
                child:Text(e.title,maxLines:2,
                  style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold))),
            ]))),
        ])),
        const SizedBox(height:21),
        _compareLine('السعر',items.map((e)=>comma(e.price)+' ر.س').toList()),
        _compareLine('المدينة',items.map((e)=>e.city).toList()),
        _compareLine('الحي',items.map((e)=>e.areaName).toList()),
        _compareLine('النوع',items.map((e)=>e.type).toList()),
        _compareLine('المساحة',items.map((e)=>e.sqm.toString()+' م²').toList()),
        _compareLine('الغرف',items.map((e)=>e.beds.toString()).toList()),
        _compareLine('الحمامات',items.map((e)=>e.baths.toString()).toList()),
        const SizedBox(height:18),
        goldAction('عرض أول عقار',()=>see(items.first)),
        const SizedBox(height:12),
        outlineAction('أضف عقاراً للمقارنة',()=>goBrowse(),icon:Icons.add),
        const SizedBox(height:12),
        TextButton(onPressed:(){
          setState(()=>compared.clear());_persist();
        },child:const Text('إزالة الكل',style:TextStyle(color:uiGold))),
      ],
      sampleBanner(),
    ]);
  }
  Widget _compareLine(String name,List<String> cells)=>Container(
    color:uiPanel,
    padding:const EdgeInsets.all(12),
    margin:const EdgeInsets.only(bottom:3),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(name,style:const TextStyle(color:uiGold,fontSize:12)),
      const SizedBox(height:8),
      Row(children:[for(final value in cells)
        Expanded(child:Text(value,textAlign:TextAlign.center,maxLines:2,
          style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)))]),
    ]));
  Widget favoritesPage() {
    final items=places.where((e)=>saved.contains(e.id)).toList();
    return ListView(padding:const EdgeInsets.all(16),children:[
      const Text('العقارات المحفوظة',style:TextStyle(
        fontSize:27,fontWeight:FontWeight.w900)),
      const SizedBox(height:9),
      Text(items.length.toString()+' عقار محفوظ على جهازك',
        style:const TextStyle(color:uiMuted)),
      if(items.isEmpty) empty(Icons.favorite_outline,'ابدأ قائمة المفضلة',
        'اضغط القلب في أي عقار لحفظه هنا.',
        'تصفح العقارات',()=>goBrowse()),
      const SizedBox(height:16),
      ...items.map(propertyTile),
      if(items.isNotEmpty)sampleBanner(),
    ]);
  }
  Widget profilePage()=>ListView(
    padding:const EdgeInsets.fromLTRB(16,24,16,30),children:[
      Center(child:Container(width:110,height:110,
        padding:const EdgeInsets.all(8),
        decoration:BoxDecoration(shape:BoxShape.circle,color:uiPanel,
          border:Border.all(color:uiGoldDim)),
        child:jawlahLogo(90))),
      const SizedBox(height:13),
      Text(widget.username==null?'مرحباً بك في جولة':'أهلاً بعودتك',
        textAlign:TextAlign.center,style:const TextStyle(
          fontSize:22,fontWeight:FontWeight.bold)),
      const SizedBox(height:6),
      Text(widget.username??'أنت تتصفح كزائر',
        textAlign:TextAlign.center,
        style:const TextStyle(color:uiMuted)),
      const SizedBox(height:19),
      if(widget.username==null)
        goldAction('دخول برقم الجوال',()=>widget.onLogin(context),
          icon:Icons.phone_android)
      else outlineAction('تسجيل الخروج',()=>widget.onLogout(context),
        icon:Icons.logout),
      headline('الخدمات والإعدادات'),
      serviceCard('حاسبة التمويل','تقدير القسط الشهري بالريال',
        Icons.calculate_outlined,openMortgage),
      serviceCard('طلبات المعاينة','مسودات محفوظة محلياً: '+viewings.length.toString(),
        Icons.event_note_outlined,showViewings),
      serviceCard('قدّم عقارك','استمارة معاينة بيانات المالك',
        Icons.add_home_work_outlined,openOwnerDraft),
      serviceCard('موقع الشركة','لعروض جولة الحقيقية',
        Icons.language,website),
      serviceCard('عن التطبيق','الإصدار 0.5.0 — عقارات مباشرة',
        Icons.info_outline,about),
      if(viewed.isNotEmpty) ...[
        headline('شوهد مؤخراً'),
        ...places.where((h)=>viewed.contains(h.id)).take(2).map(propertyTile),
      ],
      sampleBanner(),
    ]);
  void showViewings()=>Navigator.push(context,MaterialPageRoute(
    builder:(_)=>Scaffold(backgroundColor:uiBg,
      appBar:AppBar(title:const Text('طلبات المعاينة')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        const Text('هذه مسودات على الجهاز ولم يتم إرسالها للشركة.',
          style:TextStyle(color:uiGold)),
        const SizedBox(height:16),
        if(viewings.isEmpty)const Text('لا يوجد طلب محفوظ حالياً.',
          style:TextStyle(color:uiMuted)),
        for(final draft in viewings) Card(color:uiPanel,child:ListTile(
          leading:const Icon(Icons.calendar_month,color:uiGold),
          title:Text(places.where((h)=>h.id==draft.split('|').first)
            .firstOrNull?.title??'عقار'),
          subtitle:Text('موعد مقترح: '+draft.split('|').last))),
        const SizedBox(height:20),
        outlineAction('افتح موقع الشركة للتواصل',website,icon:Icons.language),
      ]))));
  void openMortgage()=>Navigator.push(context,MaterialPageRoute(
    builder:(_)=>const MortgagePage()));
  void openOwnerDraft()=>Navigator.push(context,MaterialPageRoute(
    builder:(_)=>const OwnerDraftPage()));
  void about()=>showAboutDialog(context:context,
    applicationName:'جولة العقارية',
    applicationVersion:'0.5.0',
    children:[const Text('يعرض التطبيق العقارات الجاهزة للعرض وصورها من لوحة تحكم جولة العقارية. المقارنة والمفضلة تعمل على جهازك. طلبات المعاينة ومسودات المالك لا تُرسل للشركة بعد.')]);
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:uiBg,
    body:SafeArea(child:IndexedStack(index:tab,children:[
      home(),searchPage(),comparePage(),favoritesPage(),profilePage(),
    ])),
    bottomNavigationBar:SafeArea(top:false,child:Container(
      decoration:const BoxDecoration(
        border:Border(top:BorderSide(color:uiLine))),
      child:NavigationBar(
        height:69,backgroundColor:uiPanel,
        selectedIndex:tab,indicatorColor:const Color(0xFF483820),
        onDestinationSelected:(index) {
          FocusScope.of(context).unfocus();
          setState(()=>tab=index);
          if (index == 0 || index == 1) refreshCatalog(force: false);
        },
        labelTextStyle:WidgetStateProperty.resolveWith((states)=>
          TextStyle(color:states.contains(WidgetState.selected)?uiGold:uiMuted,
            fontSize:10,fontWeight:FontWeight.bold)),
        destinations:const [
          NavigationDestination(icon:Icon(Icons.home_outlined),
            selectedIcon:Icon(Icons.home,color:uiGold),label:'الرئيسية'),
          NavigationDestination(icon:Icon(Icons.search),
            selectedIcon:Icon(Icons.search,color:uiGold),label:'بحث'),
          NavigationDestination(icon:Icon(Icons.compare_arrows),
            selectedIcon:Icon(Icons.compare,color:uiGold),label:'مقارنة'),
          NavigationDestination(icon:Icon(Icons.favorite_border),
            selectedIcon:Icon(Icons.favorite,color:uiGold),label:'المفضلة'),
          NavigationDestination(icon:Icon(Icons.person_outline),
            selectedIcon:Icon(Icons.person,color:uiGold),label:'حسابي'),
        ]))));
}
class PropertyPage extends StatefulWidget {
  final HomeInfo property;
  final bool Function() isSaved,isCompared;
  final VoidCallback flipSaved,flipCompare,onRequest;
  const PropertyPage({super.key,required this.property,
    required this.isSaved,required this.isCompared,
    required this.flipSaved,required this.flipCompare,
    required this.onRequest});
  @override State<PropertyPage> createState()=>_PropertyPageState();
}
class _PropertyPageState extends State<PropertyPage> {
  @override Widget build(BuildContext context) {
    final p=widget.property;
    return Scaffold(backgroundColor:uiBg,
      appBar:AppBar(title:const Text('تفاصيل العقار'),actions:[
        IconButton(onPressed:(){widget.flipSaved();setState((){});},
          icon:Icon(widget.isSaved()?Icons.favorite:Icons.favorite_border,
            color:uiGold)),
      ]),
      body:ListView(children:[
        SizedBox(height:280,child:Stack(fit:StackFit.expand,children:[
          propertyPicture(p.photo),
          Positioned(bottom:12,right:14,child:Container(
            padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),
            color:const Color(0xDD17191E),
            child:const Text('صورة توضيحية',style:TextStyle(
              fontSize:11,color:uiGold)))),
        ])),
        Padding(padding:const EdgeInsets.all(19),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(p.type,style:const TextStyle(color:uiGold)),
            const SizedBox(height:8),
            Text(p.title,style:const TextStyle(
              fontSize:26,fontWeight:FontWeight.w900)),
            const SizedBox(height:10),
            Text(p.city+' • '+p.areaName,
              style:const TextStyle(color:uiMuted)),
            const SizedBox(height:17),
            Text(comma(p.price)+' ر.س',style:const TextStyle(
              color:uiGold,fontSize:27,fontWeight:FontWeight.w900)),
            const Text('سعر تجريبي غير معتمد',
              style:TextStyle(color:uiMuted,fontSize:12)),
            const SizedBox(height:20),
            Wrap(spacing:18,runSpacing:13,children:[
              metric(Icons.square_foot,p.sqm.toString()+' م²'),
              if(p.beds>0)metric(Icons.bed_outlined,p.beds.toString()+' غرف'),
              if(p.baths>0)metric(Icons.bathtub_outlined,p.baths.toString()+' حمامات'),
            ]),
            const SizedBox(height:25),
            const Text('وصف العقار',style:TextStyle(
              fontSize:22,fontWeight:FontWeight.w900)),
            const SizedBox(height:10),
            const Text('نموذج عقاري توضيحي يعكس طريقة عرض العقارات في تطبيق جولة العقارية. الصور والأرقام والمدن للتجربة وليست عرضاً تجارياً فعلياً.',
              style:TextStyle(color:uiMuted,height:1.8)),
            const SizedBox(height:28),
            goldAction('حفظ طلب معاينة مبدئي',widget.onRequest,
              icon:Icons.calendar_today),
            const SizedBox(height:11),
            outlineAction(widget.isCompared()?'إزالة من المقارنة':'أضف إلى المقارنة',
              (){widget.flipCompare();setState((){});},
              icon:Icons.compare_arrows),
            sampleBanner(),
          ])),
      ]));
  }
  Widget metric(IconData icon,String title)=>Row(
    mainAxisSize:MainAxisSize.min,children:[
      Icon(icon,color:uiGold,size:21),
      const SizedBox(width:7),
      Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),
    ]);
}
class ViewingPage extends StatefulWidget {
  final HomeInfo property;
  final void Function(DateTime) onSave;
  const ViewingPage({super.key,required this.property,required this.onSave});
  @override State<ViewingPage> createState()=>_ViewingPageState();
}
class _ViewingPageState extends State<ViewingPage> {
  DateTime? proposed;
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:uiBg,
    appBar:AppBar(title:const Text('موعد معاينة مبدئي')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const Icon(Icons.calendar_month,color:uiGold,size:65),
      const SizedBox(height:17),
      Text(widget.property.title,textAlign:TextAlign.center,
        style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      const Text('احفظ الموعد المقترح على جهازك فقط',
        textAlign:TextAlign.center,style:TextStyle(color:uiMuted)),
      const SizedBox(height:26),
      outlineAction(proposed==null?'اختر تاريخاً':
        proposed!.day.toString()+'/'+proposed!.month.toString()+'/'+proposed!.year.toString(),
        () async {
          final now=DateTime.now();
          final date=await showDatePicker(context:context,
            initialDate:now.add(const Duration(days:1)),
            firstDate:now,lastDate:now.add(const Duration(days:180)));
          if(date!=null&&mounted)setState(()=>proposed=date);
        },icon:Icons.event),
      const SizedBox(height:23),
      goldAction('حفظ الموعد على الجهاز',proposed==null?null:(){
        widget.onSave(proposed!);
        showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
          backgroundColor:uiPanel,
          title:const Text('تم حفظ المسودة'),
          content:const Text('لم يتم إرسال حجز أو طلب فعلي إلى شركة جولة. يمكن التواصل مع الشركة من موقعها الرسمي.'),
          actions:[TextButton(onPressed:(){
            Navigator.pop(dialog);Navigator.pop(context);
          },child:const Text('حسناً',style:TextStyle(color:uiGold)))]));
      },icon:Icons.save_outlined),
      sampleBanner(),
    ]));
}
class OwnerDraftPage extends StatefulWidget {
  const OwnerDraftPage({super.key});
  @override State<OwnerDraftPage> createState()=>_OwnerDraftPageState();
}
class _OwnerDraftPageState extends State<OwnerDraftPage> {
  String kind='شقة',location='الرياض';
  final amount=TextEditingController();
  double size=200;
  @override void dispose(){amount.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:uiBg,
    appBar:AppBar(title:const Text('قدّم عقارك')),
    body:ListView(padding:const EdgeInsets.all(18),children:[
      const Text('تفاصيل عقارك',style:TextStyle(
        fontSize:25,fontWeight:FontWeight.w900)),
      const SizedBox(height:8),
      const Text('جهّز وصف العقار وعاين بياناتك دون نشر أو إرسال.',
        style:TextStyle(color:uiMuted)),
      const SizedBox(height:22),
      Wrap(spacing:8,children:[
        for(final item in ['فيلا','شقة','أرض'])
          ChoiceChip(label:Text(item),selected:kind==item,
            selectedColor:uiGold,showCheckmark:false,
            labelStyle:TextStyle(color:kind==item?uiBg:uiWhite),
            onSelected:(_)=>setState(()=>kind=item)),
      ]),
      const SizedBox(height:15),
      DropdownButton<String>(value:location,isExpanded:true,dropdownColor:uiPanel,
        items:['الرياض','جدة','الدمام','الخبر'].map((e)=>
          DropdownMenuItem(value:e,child:Text(e))).toList(),
        onChanged:(v){if(v!=null)setState(()=>location=v);}),
      const SizedBox(height:16),
      Text('المساحة: '+size.round().toString()+' م²'),
      Slider(value:size,min:50,max:1000,divisions:19,activeColor:uiGold,
        onChanged:(v)=>setState(()=>size=v)),
      const SizedBox(height:15),
      TextField(controller:amount,keyboardType:TextInputType.number,
        decoration:const InputDecoration(labelText:'السعر المتوقع',
          hintText:'السعر بالريال السعودي')),
      const SizedBox(height:22),
      goldAction('معاينة البيانات',(){
        final price=int.tryParse(amount.text.trim());
        if(price==null||price<1){ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('اكتب سعراً صحيحاً')));return;}
        showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
          backgroundColor:uiPanel,
          title:const Text('بيانات المسودة'),
          content:Text('النوع: '+kind+'\nالمدينة: '+location+
            '\nالمساحة: '+size.round().toString()+' م²\nالسعر: '+
            comma(price)+' ر.س\n\nلم يتم نشر أو إرسال هذه البيانات.'),
          actions:[TextButton(onPressed:()=>Navigator.pop(dialog),
            child:const Text('إغلاق',style:TextStyle(color:uiGold)))]));
      },icon:Icons.visibility_outlined),
      sampleBanner(),
    ]));
}
class MortgagePage extends StatefulWidget {
  const MortgagePage({super.key});
  @override State<MortgagePage> createState()=>_MortgagePageState();
}
class _MortgagePageState extends State<MortgagePage> {
  double price=2000000,down=20,rate=5,years=20;
  double get loan=>price*(1-down/100);
  double get installment {
    final n=years.round()*12,r=rate/1200;
    if(r==0)return loan/n;
    final power=math.pow(1+r,n).toDouble();
    return loan*r*power/(power-1);
  }
  Widget adjust(String title,String value,double number,double min,double max,
    int divisions,ValueChanged<double> onChange)=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:Text(title,style:const TextStyle(
          fontWeight:FontWeight.bold))),
        Text(value,style:const TextStyle(color:uiGold,
          fontWeight:FontWeight.bold)),
      ]),
      Slider(value:number,min:min,max:max,divisions:divisions,
        activeColor:uiGold,onChanged:onChange),
      const SizedBox(height:12),
    ]);
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:uiBg,appBar:AppBar(title:const Text('حاسبة التمويل')),
    body:ListView(padding:const EdgeInsets.all(18),children:[
      Container(padding:const EdgeInsets.all(25),
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(23),
          border:Border.all(color:uiGoldDim),
          gradient:const LinearGradient(
            colors:[Color(0xFF43331F),Color(0xFF201C17)])),
        child:Column(children:[
          const Icon(Icons.calculate_outlined,size:45,color:uiGold),
          const SizedBox(height:14),
          const Text('القسط الشهري التقريبي'),
          const SizedBox(height:12),
          Text(comma(installment.round())+' ر.س',
            style:const TextStyle(color:uiGold,
              fontWeight:FontWeight.w900,fontSize:32)),
        ])),
      const SizedBox(height:29),
      adjust('سعر العقار',comma(price.round())+' ر.س',price,
        500000,6000000,22,(v)=>setState(()=>price=v)),
      adjust('الدفعة المقدمة',down.round().toString()+'%',down,
        10,60,10,(v)=>setState(()=>down=v)),
      adjust('معدل الفائدة السنوية الافتراضي',rate.toStringAsFixed(1)+'%',rate,
        0,12,24,(v)=>setState(()=>rate=v)),
      adjust('عدد السنوات',years.round().toString()+' سنة',years,
        5,30,25,(v)=>setState(()=>years=v)),
      const SizedBox(height:8),
      Card(color:uiPanel,child:Padding(
        padding:const EdgeInsets.all(16),child:Column(children:[
          Row(children:[
            const Expanded(child:Text('مبلغ التمويل')),
            Text(comma(loan.round())+' ر.س',style:const TextStyle(color:uiGold)),
          ]),
          const SizedBox(height:12),
          Row(children:[
            const Expanded(child:Text('إجمالي الأقساط')),
            Text(comma((installment*years*12).round())+' ر.س',
              style:const TextStyle(color:uiGold)),
          ]),
        ]))),
      const SizedBox(height:16),
      const Text('تقدير رياضي وليس عرضاً من بنك. لا يشمل الرسوم والتأمين وشروط الأهلية.',
        style:TextStyle(color:uiMuted,fontSize:12,height:1.7)),
    ]));
}

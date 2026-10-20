
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const pine = Color(0xFF224A40);
const sand = Color(0xFFC7A17D);
const cream = Color(0xFFFCF9F2);
const api = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://mdar-alaakary-madar.hatchable.site');

class Property {
  final String slug, name, city, district, type, photo, description;
  final int price, area, available, total;
  const Property(this.slug,this.name,this.city,this.district,this.type,this.photo,
      this.description,this.price,this.area,this.available,this.total);
  factory Property.fromJson(Map<String,dynamic> j) => Property(
    (j['slug'] ?? '').toString(), (j['name'] ?? '').toString(),
    (j['city'] ?? '').toString(), (j['district'] ?? '').toString(),
    (j['category'] ?? '').toString(), (j['image_url'] ?? '').toString(),
    (j['description'] ?? '').toString(),
    (j['min_price'] as num?)?.toInt() ?? 0,
    (j['min_area'] as num?)?.toInt() ?? 0,
    (j['available_units'] as num?)?.toInt() ?? 0,
    (j['total_units'] as num?)?.toInt() ?? 0,
  );
}
const samples = <Property>[
  Property('rawabi-yasmin','روابي الياسمين','الرياض','حي الياسمين','فيلا',
  'https://images.unsplash.com/photo-1600047509782-20d39509f26d?auto=format&fit=crop&w=900&q=80',
  'فلل حديثة بمساحات عائلية متنوعة. البيانات تجريبية.',1800000,290,4,6),
  Property('marasi-obhur','مراسي أبحر','جدة','أبحر الشمالية','شقة',
  'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?auto=format&fit=crop&w=900&q=80',
  'شقق عصرية بأجواء ساحلية. البيانات تجريبية.',730000,110,4,6),
  Property('diyar-mohammadiya','ديار المحمدية','جدة','حي المحمدية','فيلا',
  'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=900&q=80',
  'فلل مستقلة للعائلة. البيانات تجريبية.',2150000,330,4,6),
  Property('nisf-almalqa','دار الملقا','الرياض','حي الملقا','شقة داخل فيلا',
  'https://images.unsplash.com/photo-1600566753086-00f18fb6b3ea?auto=format&fit=crop&w=900&q=80',
  'شقق مستقلة داخل فلل. البيانات تجريبية.',980000,145,4,6),
  Property('sahil-dammam','أرض الساحل','الدمام','حي الشاطئ','أرض',
  'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=900&q=80',
  'أراض سكنية في الدمام. البيانات تجريبية.',620000,320,4,6),
  Property('waha-faisaliya','واحة الفيصلية','الدمام','حي الفيصلية','شقة',
  'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=900&q=80',
  'شقق مريحة بمرافق مشتركة. البيانات تجريبية.',560000,100,4,6)
];
String money(int n) {
  final s=n.toString();
  return s.replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')+' ر.س';
}
Future<void> openLink(String url) async {
  final uri=Uri.parse(url);
  await launchUrl(uri,mode:LaunchMode.externalApplication);
}
void main()=>runApp(const JawlahApp());
class JawlahApp extends StatelessWidget {
  const JawlahApp({super.key});
  @override
  Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'جولة العقارية',
    theme:ThemeData(
      useMaterial3:true,
      scaffoldBackgroundColor:cream,
      colorScheme:ColorScheme.fromSeed(seedColor:pine,surface:cream),
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(
        backgroundColor:pine,foregroundColor:Colors.white,
        minimumSize:const Size(50,50))),
    ),
    home:const Directionality(textDirection:TextDirection.rtl,child:AppHome()),
  );
}
class AppHome extends StatefulWidget {
  const AppHome({super.key});
  @override
  State<AppHome> createState()=>_AppHomeState();
}
class _AppHomeState extends State<AppHome> {
  List<Property> listings=samples;
  final search=TextEditingController();
  Set<String> saved={};
  String city='الكل',type='الكل';
  int tab=0;
  bool demo=true,loading=true;
  @override
  void initState(){
    super.initState();
    search.addListener(_changed);
    _loadSaved();
    _fetch();
  }
  void _changed(){if(mounted)setState((){});}
  @override
  void dispose(){search.removeListener(_changed);search.dispose();super.dispose();}
  Future<void> _loadSaved() async {
    final prefs=await SharedPreferences.getInstance();
    if(mounted)setState(()=>saved=(prefs.getStringList('favorites')??[]).toSet());
  }
  Future<void> _fetch() async {
    setState(()=>loading=true);
    try {
      final r=await http.get(Uri.parse(api+'/api/projects')).timeout(const Duration(seconds:7));
      if(r.statusCode!=200 || !(r.headers['content-type']??'').contains('json')) throw const FormatException('private site');
      final decoded=jsonDecode(utf8.decode(r.bodyBytes)) as Map<String,dynamic>;
      final all=(decoded['projects'] as List).map((e)=>Property.fromJson(e as Map<String,dynamic>)).toList();
      if(all.isNotEmpty && mounted)setState((){listings=all;demo=false;});
    }catch(_){
      if(mounted)setState((){listings=samples;demo=true;});
    }finally{
      if(mounted)setState(()=>loading=false);
    }
  }
  Future<void> _favorite(Property p) async {
    setState((){
      if(saved.contains(p.slug)){saved.remove(p.slug);}else{saved.add(p.slug);}
    });
    final prefs=await SharedPreferences.getInstance();
    await prefs.setStringList('favorites',saved.toList());
  }
  List<Property> get matching => listings.where((p){
    final q=search.text.trim();
    return (q.isEmpty || (p.name+p.city+p.district+p.type).contains(q)) &&
      (city=='الكل'||p.city==city) && (type=='الكل'||p.type==type);
  }).toList();
  Widget _photo(Property p,double height)=>Image.network(p.photo,
    height:height,width:double.infinity,fit:BoxFit.cover,
    errorBuilder:(context,error,trace)=>Container(height:height,
      color:const Color(0xFFD8E2D9),
      child:const Icon(Icons.apartment,color:pine,size:58)));
  Widget _filters()=>Padding(
    padding:const EdgeInsets.symmetric(horizontal:16),
    child:Column(children:[
      TextField(controller:search,decoration:InputDecoration(
        hintText:'ابحث عن مشروع أو مدينة أو حي',prefixIcon:const Icon(Icons.search),
        filled:true,fillColor:Colors.white,
        border:OutlineInputBorder(borderSide:BorderSide.none,
          borderRadius:BorderRadius.circular(16)))),
      const SizedBox(height:10),
      Row(children:[
        Expanded(child:_select(city,['الكل','الرياض','جدة','الدمام'],
          (v)=>setState(()=>city=v))),
        const SizedBox(width:10),
        Expanded(child:_select(type,['الكل','فيلا','شقة','شقة داخل فيلا','أرض'],
          (v)=>setState(()=>type=v)))
      ]),
    ]),
  );
  Widget _select(String current,List<String> options,ValueChanged<String> change)=>
    Container(padding:const EdgeInsets.symmetric(horizontal:10),
      decoration:BoxDecoration(color:Colors.white,
        borderRadius:BorderRadius.circular(12)),
      child:DropdownButtonHideUnderline(child:DropdownButton<String>(
        value:current,isExpanded:true,
        items:options.map((o)=>DropdownMenuItem(value:o,child:Text(o,
          overflow:TextOverflow.ellipsis))).toList(),
        onChanged:(v){if(v!=null)change(v);}
      )));
  Widget _notice()=>Container(
    margin:const EdgeInsets.symmetric(horizontal:16,vertical:8),
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(color:const Color(0xFFFFF0D9),
      borderRadius:BorderRadius.circular(12)),
    child:const Row(children:[
      Icon(Icons.info_outline,color:Color(0xFF8B6840)),
      SizedBox(width:8),
      Expanded(child:Text('الصور والأسعار والمشاريع المعروضة توضيحية وليست عروض بيع حقيقية.',
        style:TextStyle(fontSize:12,color:Color(0xFF725439)))),
    ])
  );
  Widget _card(Property p)=>Card(
    color:Colors.white,clipBehavior:Clip.antiAlias,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(19)),
    margin:const EdgeInsets.fromLTRB(16,0,16,16),
    child:InkWell(
      onTap:()=>Navigator.push(context,MaterialPageRoute(
        builder:(_)=>Directionality(textDirection:TextDirection.rtl,
          child:PropertyDetails(
            property:p,
            favorited:saved.contains(p.slug),
            toggle:()=>_favorite(p),
          )))).then((_){if(mounted)setState((){});}),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Stack(children:[
          _photo(p,185),
          Positioned(top:10,right:10,child:Chip(label:Text(p.type),
            backgroundColor:cream)),
          Positioned(left:8,top:8,child:IconButton.filledTonal(
            icon:Icon(saved.contains(p.slug)?Icons.favorite:Icons.favorite_border,
              color:saved.contains(p.slug)?Colors.redAccent:pine),
            onPressed:()=>_favorite(p))),
        ]),
        Padding(padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(p.name,style:const TextStyle(fontSize:20,
              fontWeight:FontWeight.bold,color:pine)),
            const SizedBox(height:4),
            Text(p.city+'، '+p.district,style:const TextStyle(color:Colors.black54)),
            const SizedBox(height:12),
            Row(children:[
              const Icon(Icons.square_foot,size:18,color:sand),
              Text(' '+p.area.toString()+' م²'),
              const SizedBox(width:18),
              const Icon(Icons.check_circle_outline,size:18,color:sand),
              Text(' '+p.available.toString()+' متاح')
            ]),
            const Divider(height:25),
            Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
              Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('يبدأ من',style:TextStyle(color:Colors.black54)),
                Text(money(p.price),style:const TextStyle(fontSize:20,
                  fontWeight:FontWeight.bold,color:pine)),
              ]),
              const Icon(Icons.arrow_circle_left_outlined,color:pine,size:32)
            ]),
          ]))
      ]),
    ),
  );
  // Landing experience inspired by the Jawlah website's photographic hero.
  Widget _header()=>Container(
    height:445,
    margin:const EdgeInsets.fromLTRB(16,12,16,12),
    clipBehavior:Clip.antiAlias,
    decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(24),
      color:pine,
      boxShadow:const [BoxShadow(color:Color(0x220F352F),
        blurRadius:22,offset:Offset(0,9))],
    ),
    child:Stack(fit:StackFit.expand,children:[
      Image.network(
        'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1200&q=85',
        fit:BoxFit.cover,
        errorBuilder:(_,__,___)=>const ColoredBox(
          color:pine,child:Center(child:Icon(Icons.home_work_outlined,
            size:92,color:Color(0x66FFFFFF)))),
      ),
      const DecoratedBox(decoration:BoxDecoration(
        gradient:LinearGradient(begin:Alignment.topCenter,
          end:Alignment.bottomCenter,
          colors:[Color(0x50102C2B),Color(0x96102C2B),Color(0xF7102C2B)],
          stops:[0,0.48,1]),
      )),
      Padding(padding:const EdgeInsets.fromLTRB(23,21,23,26),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(
            padding:const EdgeInsets.symmetric(horizontal:13,vertical:9),
            decoration:BoxDecoration(color:const Color(0x88102C2B),
              border:Border.all(color:const Color(0x77EAD6B6)),
              borderRadius:BorderRadius.circular(30)),
            child:const Row(mainAxisSize:MainAxisSize.min,children:[
              Icon(Icons.diamond_outlined,color:Color(0xFFEAD1A9),size:17),
              SizedBox(width:7),
              Text('جولة العقارية  |  JAWLAH',
                style:TextStyle(color:Colors.white,fontSize:12,
                  fontWeight:FontWeight.bold)),
            ]),
          ),
          const Spacer(),
          const Text('اختيارات تصنع الفرق',
            style:TextStyle(fontSize:14,color:Color(0xFFE9CBAC),
              fontWeight:FontWeight.w700)),
          const SizedBox(height:10),
          const Text('بيتك مش مجرد مكان.\nدي بداية حكاية.',
            style:TextStyle(color:Colors.white,fontSize:32,
              fontWeight:FontWeight.bold,height:1.38)),
          const SizedBox(height:11),
          const Text('فلل، شقق وأراضٍ بمساحات متنوعة.\nابدأ جولتك واكتشف اللي يناسبك.',
            style:TextStyle(color:Color(0xFFF1EDE5),
              fontSize:13,height:1.7)),
          const SizedBox(height:23),
          Row(children:[
            Expanded(child:FilledButton.icon(
              style:FilledButton.styleFrom(
                backgroundColor:const Color(0xFFEACBA9),
                foregroundColor:const Color(0xFF173B39),
                padding:const EdgeInsets.symmetric(vertical:13)),
              onPressed:()=>setState(()=>tab=1),
              icon:const Icon(Icons.arrow_back),
              label:const Text('اكتشف المشاريع',
                style:TextStyle(fontWeight:FontWeight.bold)),
            )),
            const SizedBox(width:9),
            OutlinedButton(
              style:OutlinedButton.styleFrom(
                foregroundColor:Colors.white,
                side:const BorderSide(color:Color(0xFFE3D8C3)),
                padding:const EdgeInsets.symmetric(
                  horizontal:14,vertical:14)),
              onPressed:()=>openLink('https://wa.me/966567607764'),
              child:const Text('تواصل معنا'),
            ),
          ]),
        ]),
      ),
    ]),
  );
  Widget _category(String name,IconData icon)=>ActionChip(
    avatar:Icon(icon,color:pine,size:19),
    label:Text(name,style:const TextStyle(color:pine,fontWeight:FontWeight.w600)),
    backgroundColor:Colors.white,
    side:const BorderSide(color:Color(0xFFDCE5DC)),
    onPressed:(){
      search.clear();
      setState((){
        city='الكل';
        type=name;
        tab=1;
      });
    },
  );
  Widget _home()=>RefreshIndicator(onRefresh:_fetch,child:ListView(children:[
    _header(),
    if(demo)_notice(),
    const Padding(padding:EdgeInsets.fromLTRB(16,17,16,10),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('اعثر على المساحة اللي تشبهك',
          style:TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:pine)),
        SizedBox(height:4),
        Text('اختار نوع العقار وابدأ استكشاف المشاريع',
          style:TextStyle(color:Colors.black54,fontSize:13)),
      ])),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),
      child:Wrap(spacing:8,runSpacing:5,children:[
        _category('فيلا',Icons.villa_outlined),
        _category('شقة',Icons.apartment_outlined),
        _category('أرض',Icons.landscape_outlined),
      ])),
    const Padding(padding:EdgeInsets.fromLTRB(16,25,16,11),
      child:Text('ابحث عن عقارك',
        style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:pine))),
    _filters(),
    Padding(padding:const EdgeInsets.fromLTRB(16,23,16,13),
      child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        const Expanded(child:Text('مشاريع تستحق الاستكشاف',
          style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:pine))),
        TextButton(onPressed:()=>setState(()=>tab=1),
          child:const Text('عرض الكل')),
      ])),
    ...matching.take(4).map(_card),
    if(matching.isEmpty)const Padding(padding:EdgeInsets.all(24),
      child:Center(child:Text('لا توجد نتائج مطابقة'))),
    Container(margin:const EdgeInsets.fromLTRB(16,5,16,28),
      padding:const EdgeInsets.all(20),
      decoration:BoxDecoration(
        color:const Color(0xFFE8E6D8),
        borderRadius:BorderRadius.circular(19)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('محتاج مساعدة في الاختيار؟',
          style:TextStyle(color:pine,fontSize:20,
            fontWeight:FontWeight.bold)),
        const SizedBox(height:6),
        const Text('تواصل مع فريق جولة للاستفسار عن المشاريع.',
          style:TextStyle(color:Color(0xFF4A6359))),
        const SizedBox(height:15),
        FilledButton.icon(
          onPressed:()=>openLink('https://wa.me/966567607764'),
          icon:const Icon(Icons.chat_bubble_outline),
          label:const Text('تواصل عبر واتساب')),
      ]),
    ),
  ]));
  Widget _list({bool onlyFav=false}) {
    final items=onlyFav
      ?listings.where((p)=>saved.contains(p.slug)).toList():matching;
    return RefreshIndicator(onRefresh:_fetch,child:ListView(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,24,16,16),
        child:Text(onlyFav?'المفضلة':'المشاريع العقارية',
          style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold,color:pine))),
      if(!onlyFav)_filters(),
      if(demo)_notice(),
      const SizedBox(height:12),
      if(items.isEmpty)Padding(padding:const EdgeInsets.all(28),
        child:Center(child:Text(onlyFav
          ?'اضغط علامة القلب على أي عقار لحفظه هنا':'لا توجد نتائج مطابقة'))),
      ...items.map(_card),
      const SizedBox(height:25),
    ]));
  }
  Widget _info()=>ListView(padding:const EdgeInsets.all(22),children:[
    const SizedBox(height:10),
    const Icon(Icons.real_estate_agent,color:pine,size:68),
    const SizedBox(height:8),
    const Center(child:Text('جولة العقارية',style:TextStyle(fontSize:29,
      color:pine,fontWeight:FontWeight.bold))),
    const SizedBox(height:16),
    const Text('استكشف عقارات المملكة، واحفظ المفضلة وتواصل للاستفسار.',
      style:TextStyle(fontSize:16,height:1.8),textAlign:TextAlign.center),
    const SizedBox(height:25),
    ListTile(leading:const Icon(Icons.chat_outlined),title:const Text('واتساب'),
      onTap:()=>openLink('https://wa.me/966567607764')),
    ListTile(leading:const Icon(Icons.phone_outlined),title:const Text('اتصال مباشر'),
      onTap:()=>openLink('tel:+966567607764')),
    ListTile(leading:const Icon(Icons.web_outlined),title:const Text('الموقع الإلكتروني'),
      onTap:()=>openLink(api)),
    ListTile(leading:const Icon(Icons.refresh),title:const Text('تحديث العقارات'),
      onTap:_fetch),
    _notice(),
    const SizedBox(height:22),
    const Center(child:Text('نسخة أندرويد تجريبية 0.1.0',
      style:TextStyle(color:Colors.black54))),
  ]);
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(
      title:const Text('جولة | JAWLAH',
        style:TextStyle(fontWeight:FontWeight.bold,color:pine)),
      leading:loading?const Padding(padding:EdgeInsets.all(14),
        child:CircularProgressIndicator(strokeWidth:2)):null,
      actions:[IconButton(onPressed:()=>openLink('https://wa.me/966567607764'),
        icon:const Icon(Icons.support_agent_outlined))],
    ),
    body:IndexedStack(index:tab,children:[
      _home(),_list(),_list(onlyFav:true),_info()
    ]),
    bottomNavigationBar:NavigationBar(
      selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
      backgroundColor:Colors.white,
      destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),label:'الرئيسية'),
        NavigationDestination(icon:Icon(Icons.apartment_outlined),label:'المشاريع'),
        NavigationDestination(icon:Icon(Icons.favorite_outline),label:'المفضلة'),
        NavigationDestination(icon:Icon(Icons.more_horiz),label:'المزيد'),
      ],
    ),
  );
}
class PropertyDetails extends StatefulWidget {
  final Property property;
  final bool favorited;
  final VoidCallback toggle;
  const PropertyDetails({super.key,required this.property,
    required this.favorited,required this.toggle});
  @override
  State<PropertyDetails> createState()=>_PropertyDetailsState();
}
class _PropertyDetailsState extends State<PropertyDetails> {
  late bool fav=widget.favorited;
  @override
  Widget build(BuildContext context) {
    final p=widget.property;
    return Scaffold(
      appBar:AppBar(title:Text(p.name),actions:[
        IconButton(onPressed:(){widget.toggle();setState(()=>fav=!fav);},
          icon:Icon(fav?Icons.favorite:Icons.favorite_outline,
            color:fav?Colors.redAccent:pine)),
      ]),
      body:ListView(children:[
        Image.network(p.photo,width:double.infinity,height:255,
          fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(height:255,
            color:const Color(0xFFDDE6DB),child:const Icon(Icons.home_work,size:76))),
        Padding(padding:const EdgeInsets.all(22),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(p.type,style:const TextStyle(color:Color(0xFFA67954),fontSize:16)),
            const SizedBox(height:8),
            Text(p.name,style:const TextStyle(color:pine,fontWeight:FontWeight.bold,fontSize:29)),
            const SizedBox(height:7),
            Text(p.city+'، '+p.district,style:const TextStyle(color:Colors.black54)),
            const SizedBox(height:19),
            Text('يبدأ من '+money(p.price),style:const TextStyle(
              color:pine,fontSize:24,fontWeight:FontWeight.bold)),
            const SizedBox(height:16),
            Wrap(spacing:9,children:[
              Chip(label:Text('من '+p.area.toString()+' م²')),
              Chip(label:Text(p.available.toString()+' من '+p.total.toString()+' متاح')),
            ]),
            const SizedBox(height:25),
            const Text('عن المشروع',style:TextStyle(
              fontWeight:FontWeight.bold,fontSize:20,color:pine)),
            const SizedBox(height:8),
            Text(p.description,style:const TextStyle(fontSize:16,height:1.7)),
            const SizedBox(height:19),
            const Card(color:Color(0xFFFFEED6),child:Padding(
              padding:EdgeInsets.all(12),
              child:Text('البيانات والصور توضيحية فقط وليست عروضًا عقارية فعلية.',
                style:TextStyle(fontSize:13)))),
            const SizedBox(height:22),
            SizedBox(width:double.infinity,child:FilledButton.icon(
              icon:const Icon(Icons.chat_outlined),
              label:const Text('استفسر عن المشروع'),
              onPressed:()=>openLink('https://wa.me/966567607764?text='+
                Uri.encodeComponent('أريد الاستفسار عن مشروع '+p.name)))),
            const SizedBox(height:10),
            SizedBox(width:double.infinity,child:OutlinedButton.icon(
              icon:const Icon(Icons.phone),
              label:const Text('اتصل بنا'),
              onPressed:()=>openLink('tel:+966567607764'))),
          ])),
      ]),
    );
  }
}

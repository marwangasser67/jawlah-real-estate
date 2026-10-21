import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';

class AdminSiteSettings extends StatefulWidget{
  final Map<String,dynamic> settings;
  final List<Map<String,dynamic>> projects;
  final List<Map<String,dynamic>> blocks;
  final Future<bool> Function(Map<String,dynamic>) onSave;
  final VoidCallback onAdd;
  final void Function(Map<String,dynamic>) onEdit;
  final void Function(Map<String,dynamic>) onDelete;

  const AdminSiteSettings({super.key,required this.settings,
    required this.projects,required this.blocks,
    required this.onSave,required this.onAdd,required this.onEdit,
    required this.onDelete});

  @override State<AdminSiteSettings> createState()=>_AdminSiteSettingsState();
}
class _AdminSiteSettingsState extends State<AdminSiteSettings>{
  late final TextEditingController company,tagline,headline,summary,
    badge,featuredTitle,featuredSubtitle,announcement,whatsapp,phone;
  late String hero;
  late bool announcementOn,comparison,calculator,viewings,ownerSubmit;
  bool saving=false;

  String orDefault(String key,String fallback){
    final s=asText(widget.settings[key]);
    return s.isEmpty?fallback:s;
  }
  @override void initState(){
    super.initState();
    company=TextEditingController(text:orDefault('app_name','جولة العقارية'));
    tagline=TextEditingController(text:orDefault('tagline','مساحتك تبدأ من هنا'));
    headline=TextEditingController(text:orDefault('hero_title','اكتشف بيت أحلامك'));
    summary=TextEditingController(text:orDefault('hero_subtitle',
      'مشاريع وعقارات في السعودية'));
    badge=TextEditingController(text:orDefault('hero_badge','جولة العقارية'));
    featuredTitle=TextEditingController(
      text:orDefault('featured_title','مشاريع جولة المنشورة'));
    featuredSubtitle=TextEditingController(
      text:orDefault('featured_subtitle','عقارات مختارة من الشركة'));
    announcement=TextEditingController(text:asText(widget.settings['announcement']));
    whatsapp=TextEditingController(text:asText(widget.settings['contact_whatsapp']));
    phone=TextEditingController(text:asText(widget.settings['contact_phone']));
    hero=asText(widget.settings['hero_project_id']);
    announcementOn=widget.settings['announcement_enabled']==true;
    comparison=widget.settings['show_comparison']!=false;
    calculator=widget.settings['show_calculator']!=false;
    viewings=widget.settings['show_viewings']!=false;
    ownerSubmit=widget.settings['show_owner_submission']!=false;
  }
  @override void dispose(){
    for(final c in [company,tagline,headline,summary,badge,
      featuredTitle,featuredSubtitle,announcement,whatsapp,phone]){
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save()async{
    if(saving)return;
    setState(()=>saving=true);
    final changed={
      'app_name':company.text.trim(),
      'tagline':tagline.text.trim(),
      'hero_title':headline.text.trim(),
      'hero_subtitle':summary.text.trim(),
      'hero_badge':badge.text.trim(),
      'featured_title':featuredTitle.text.trim(),
      'featured_subtitle':featuredSubtitle.text.trim(),
      'hero_project_id':hero,
      'announcement':announcement.text.trim(),
      'announcement_enabled':announcementOn,
      'show_comparison':comparison,
      'show_calculator':calculator,
      'show_viewings':viewings,
      'show_owner_submission':ownerSubmit,
      'contact_whatsapp':whatsapp.text.trim(),
      'contact_phone':phone.text.trim(),
    };
    final saved=await widget.onSave(changed);
    if(!mounted)return;
    setState(()=>saving=false);
    if(saved)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:Text('تم تحديث محتوى تطبيق العملاء بنجاح.')));
  }

  Widget toggle(String name,bool value,ValueChanged<bool> changed)=>
    SwitchListTile.adaptive(
      value:value,activeColor:aGold,
      contentPadding:EdgeInsets.zero,
      title:Text(name,style:const TextStyle(fontSize:14)),
      onChanged:changed);

  @override Widget build(BuildContext context){
    final projects=widget.projects.where((p)=>p['status']=='published').toList();
    return ListView(key:const PageStorageKey('admin-content'),
      padding:const EdgeInsets.fromLTRB(15,14,15,100),children:[
      adminTitle('تخصيص تطبيق العملاء',
        subtitle:'تحكم في محتوى تطبيق جولة بشكل مباشر'),
      panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('الهوية والصفحة الرئيسية',style:TextStyle(
          fontSize:18,fontWeight:FontWeight.w900)),
        const SizedBox(height:15),
        adminInput(company,'اسم الشركة في التطبيق'),
        const SizedBox(height:11),
        adminInput(tagline,'العبارة التعريفية'),
        const SizedBox(height:11),
        adminInput(headline,'عنوان الصورة الرئيسية'),
        const SizedBox(height:11),
        adminInput(summary,'الوصف داخل الصورة الرئيسية',lines:2),
        const SizedBox(height:11),
        adminInput(badge,'شارة أعلى الصورة'),
        const SizedBox(height:11),
        adminSelect('العقار المميز للواجهة',hero,[
          const MapEntry('','أول عقار منشور تلقائيًا'),
          ...projects.map((p)=>
            MapEntry(asText(p['id']),asText(p['title']))),
        ],(v)=>setState(()=>hero=v)),
        const SizedBox(height:13),
        adminInput(featuredTitle,'عنوان قسم العقارات'),
        const SizedBox(height:11),
        adminInput(featuredSubtitle,'وصف قسم العقارات'),
      ])),
      const SizedBox(height:14),
      panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('الإعلانات والخدمات',style:TextStyle(
          fontSize:18,fontWeight:FontWeight.w900)),
        const SizedBox(height:13),
        adminInput(announcement,'رسالة أو إعلان للعملاء',lines:3),
        toggle('عرض الإعلان أعلى الصفحة',announcementOn,
          (v)=>setState(()=>announcementOn=v)),
        const Divider(color:aLine),
        toggle('إظهار المقارنة',comparison,(v)=>setState(()=>comparison=v)),
        toggle('إظهار حاسبة التمويل',calculator,(v)=>setState(()=>calculator=v)),
        toggle('إظهار طلب معاينة',viewings,(v)=>setState(()=>viewings=v)),
        toggle('إظهار تقديم العقار',ownerSubmit,
          (v)=>setState(()=>ownerSubmit=v)),
      ])),
      const SizedBox(height:14),
      panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('بيانات التواصل',style:TextStyle(
          fontSize:18,fontWeight:FontWeight.w900)),
        const SizedBox(height:12),
        adminInput(whatsapp,'واتساب الشركة مع رمز الدولة',
          keyboard:TextInputType.phone),
        const SizedBox(height:11),
        adminInput(phone,'رقم اتصال الشركة',keyboard:TextInputType.phone),
      ])),
      const SizedBox(height:14),
      goldButton(saving?'جارٍ حفظ الإعدادات...':'حفظ إعدادات تطبيق العملاء',
        saving?null:save,icon:Icons.save_outlined),
      const SizedBox(height:28),
      Row(children:[
        const Expanded(child:Text('العروض والأقسام الإضافية',
          style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))),
        IconButton(tooltip:'إضافة قسم جديد',
          onPressed:widget.onAdd,
          icon:const Icon(Icons.add_circle_outline,color:aGold)),
      ]),
      const SizedBox(height:9),
      if(widget.blocks.isEmpty)
        adminEmpty(Icons.dashboard_customize_outlined,'لسه مفيش عروض إضافية',
          'اعمل قسم جديد واربطه بعقار منشور.')
      else for(final b in widget.blocks) ...[
        panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            const Icon(Icons.auto_awesome_outlined,color:aGold,size:26),
            const SizedBox(width:9),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(asText(b['title']),
                  style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
                Text(asText(b['subtitle']),maxLines:3,
                  style:const TextStyle(fontSize:12,color:aMuted)),
              ])),
          ]),
          const SizedBox(height:8),
          Text((b['is_visible']==true?'ظاهر للعملاء':'مخفي')+
            ' • الترتيب: '+asText(b['display_order']),
            style:const TextStyle(color:aGold,fontSize:11)),
          const SizedBox(height:11),
          Row(children:[
            Expanded(child:outlinedAction('تعديل',
              ()=>widget.onEdit(b),icon:Icons.edit_outlined)),
            IconButton(onPressed:()=>widget.onDelete(b),
              icon:const Icon(Icons.delete_outline,color:aRed))
          ]),
        ])),
        const SizedBox(height:10),
      ],
      outlinedAction('إضافة عرض / قسم جديد',widget.onAdd,icon:Icons.add),
      const SizedBox(height:14),
      const Text('مهم: تغيير النصوص والعروض والأسعار يظهر بعد تحديث تطبيق العملاء. إضافة وظيفة برمجية جديدة بالكامل تحتاج إصدار تطبيق جديد.',
        style:TextStyle(color:aMuted,fontSize:11,height:1.7)),
    ]);
  }
}

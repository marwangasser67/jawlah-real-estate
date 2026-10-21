import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';

class AdminFormResult {
  static Future<Map<String,dynamic>?> editProject(
    BuildContext context, {Map<String,dynamic>? original}) async {
    final title=TextEditingController(text:asText(original?['title']));
    final city=TextEditingController(text:asText(original?['city']));
    final district=TextEditingController(text:asText(original?['district']));
    final type=TextEditingController(text:asText(original?['property_type']).isEmpty
      ?'شقة':asText(original?['property_type']));
    final price=TextEditingController(text:asText(original?['price_sar']).isEmpty
      ?'0':asText(original?['price_sar']));
    final area=TextEditingController(text:asText(original?['area_sqm']).isEmpty
      ?'0':asText(original?['area_sqm']));
    final bedrooms=TextEditingController(text:asText(original?['bedrooms']).isEmpty
      ?'0':asText(original?['bedrooms']));
    final bathrooms=TextEditingController(text:asText(original?['bathrooms']).isEmpty
      ?'0':asText(original?['bathrooms']));
    final description=TextEditingController(text:asText(original?['description']));
    String status=asText(original?['status']);
    if(status.isEmpty)status='draft';
    final key=GlobalKey<FormState>();
    final result=await showModalBottomSheet<Map<String,dynamic>>(
      context:context,isScrollControlled:true,useSafeArea:true,
      backgroundColor:aPanel,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
        padding:EdgeInsets.fromLTRB(18,18,18,
          MediaQuery.of(ctx).viewInsets.bottom+20),
        child:SingleChildScrollView(child:Form(
          key:key,child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            mainAxisSize:MainAxisSize.min,children:[
            adminTitle(original==null?'إضافة عقار':'تعديل العقار',
              subtitle:'كل التغييرات ستُحفظ في قاعدة بيانات جولة'),
            adminInput(title,'اسم العقار أو المشروع',required:true),
            const SizedBox(height:12),
            Row(children:[
              Expanded(child:adminInput(city,'المدينة',required:true)),
              const SizedBox(width:9),
              Expanded(child:adminInput(district,'الحي')),
            ]),
            const SizedBox(height:12),
            adminInput(type,'نوع العقار — اكتب نوع جديد لو عايز',
              required:true),
            const SizedBox(height:12),
            Row(children:[
              Expanded(child:adminInput(price,'السعر بالريال',
                keyboard:TextInputType.number)),
              const SizedBox(width:9),
              Expanded(child:adminInput(area,'المساحة م²',
                keyboard:TextInputType.number)),
            ]),
            const SizedBox(height:12),
            Row(children:[
              Expanded(child:adminInput(bedrooms,'الغرف',
                keyboard:TextInputType.number)),
              const SizedBox(width:9),
              Expanded(child:adminInput(bathrooms,'الحمامات',
                keyboard:TextInputType.number)),
            ]),
            const SizedBox(height:12),
            adminInput(description,'الوصف',lines:4),
            const SizedBox(height:12),
            adminSelect('حالة النشر',status,staticOptions({
              'draft':'مسودة — غير ظاهر للعملاء',
              'published':'جاهز للعرض للعملاء',
              'archived':'مؤرشف'
            }),(v)=>update(()=>status=v)),
            const SizedBox(height:18),
            goldButton('حفظ العقار',(){
              if(!key.currentState!.validate())return;
              Navigator.pop(ctx,{
                if(original!=null)'id':original['id'],
                'title':title.text.trim(),'city':city.text.trim(),
                'district':district.text.trim(),'property_type':type.text.trim(),
                'price_sar':num.tryParse(price.text)??0,
                'area_sqm':num.tryParse(area.text)??0,
                'bedrooms':int.tryParse(bedrooms.text)??0,
                'bathrooms':int.tryParse(bathrooms.text)??0,
                'description':description.text.trim(),'status':status
              });
            },icon:Icons.save_outlined),
          ]))),
      )),
    );
    for(final c in [title,city,district,type,price,area,bedrooms,bathrooms,description]){
      c.dispose();
    }
    return result;
  }

  static Future<Map<String,dynamic>?> editClient(
      BuildContext context,List<Map<String,dynamic>> projects,
      {Map<String,dynamic>? original}) async {
    final name=TextEditingController(text:asText(original?['full_name']));
    final phone=TextEditingController(text:asText(original?['phone']));
    final email=TextEditingController(text:asText(original?['email']));
    final source=TextEditingController(text:asText(original?['source']).isEmpty
      ?'تواصل مباشر':asText(original?['source']));
    final notes=TextEditingController(text:asText(original?['notes']));
    String stage=asText(original?['stage']);
    if(stage.isEmpty)stage='new';
    String linked=asText(original?['project_id']);
    final key=GlobalKey<FormState>();
    final result=await showModalBottomSheet<Map<String,dynamic>>(
      context:context,isScrollControlled:true,useSafeArea:true,
      backgroundColor:aPanel,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
        padding:EdgeInsets.fromLTRB(18,18,18,
          MediaQuery.of(ctx).viewInsets.bottom+20),
        child:SingleChildScrollView(child:Form(key:key,
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            mainAxisSize:MainAxisSize.min,children:[
            adminTitle(original==null?'إضافة عميل':'تعديل العميل',
              subtitle:'البيانات خاصة بمدير جولة فقط'),
            adminInput(name,'اسم العميل',required:true),
            const SizedBox(height:12),
            adminInput(phone,'رقم الهاتف',keyboard:TextInputType.phone),
            const SizedBox(height:12),
            adminInput(email,'البريد الإلكتروني',keyboard:TextInputType.emailAddress),
            const SizedBox(height:12),
            adminSelect('مرحلة المتابعة',stage,staticOptions({
              'new':'جديد','contacted':'تم التواصل','visit':'معاينة',
              'negotiating':'تفاوض','won':'تم الاتفاق','lost':'لم يكتمل',
            }),(v)=>update(()=>stage=v)),
            const SizedBox(height:12),
            adminSelect('العقار المرتبط',linked,[
              const MapEntry('','بدون عقار'),
              ...projects.map((p)=>MapEntry(asText(p['id']),
                asText(p['title'])))
            ],(v)=>update(()=>linked=v)),
            const SizedBox(height:12),
            adminInput(source,'مصدر العميل'),
            const SizedBox(height:12),
            adminInput(notes,'ملاحظات المتابعة',lines:4),
            const SizedBox(height:18),
            goldButton('حفظ العميل',(){
              if(!key.currentState!.validate())return;
              Navigator.pop(ctx,{
                if(original!=null)'id':original['id'],
                'full_name':name.text.trim(),'phone':phone.text.trim(),
                'email':email.text.trim(),'stage':stage,
                'project_id':linked,'source':source.text.trim(),
                'notes':notes.text.trim(),
              });
            },icon:Icons.save_outlined),
          ]))),
      )),
    );
    for(final c in [name,phone,email,source,notes]){c.dispose();}
    return result;
  }

  static Future<Map<String,dynamic>?> editFinance(
      BuildContext context,List<Map<String,dynamic>> projects,
      List<Map<String,dynamic>> clients,
      {Map<String,dynamic>? original,String initialType='income'}) async {
    String type=asText(original?['entry_type']);
    if(type.isEmpty)type=initialType;
    final category=TextEditingController(text:asText(original?['category']));
    final amount=TextEditingController(text:asText(original?['amount_sar']));
    final notes=TextEditingController(text:asText(original?['note']));
    String projectId=asText(original?['project_id']);
    String customerId=asText(original?['customer_id']);
    String date=asText(original?['entry_date']);
    if(date.length>=10)date=date.substring(0,10);
    if(date.isEmpty)date=DateTime.now().toIso8601String().substring(0,10);
    final key=GlobalKey<FormState>();
    final result=await showModalBottomSheet<Map<String,dynamic>>(
      context:context,isScrollControlled:true,useSafeArea:true,
      backgroundColor:aPanel,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
        padding:EdgeInsets.fromLTRB(18,18,18,
          MediaQuery.of(ctx).viewInsets.bottom+20),
        child:SingleChildScrollView(child:Form(key:key,
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            mainAxisSize:MainAxisSize.min,children:[
            adminTitle(original==null?'تسجيل حركة مالية':'تعديل حركة مالية',
              subtitle:'المبالغ بالريال السعودي'),
            adminSelect('نوع الحركة',type,staticOptions({
              'income':'إيراد +','expense':'مصروف −',
            }),(v)=>update(()=>type=v)),
            const SizedBox(height:12),
            adminInput(amount,'المبلغ',keyboard:TextInputType.number,
              required:true),
            const SizedBox(height:12),
            adminInput(category,'التصنيف — عمولة، تسويق، تشغيل...',
              required:true),
            const SizedBox(height:12),
            outlinedAction('تاريخ القيد: '+date,()async{
              final today=DateTime.now();
              final picked=await showDatePicker(context:ctx,
                initialDate:DateTime.tryParse(date)??today,
                firstDate:DateTime(2020),lastDate:today.add(const Duration(days:366)));
              if(picked!=null)update(()=>date=picked.toIso8601String().substring(0,10));
            },icon:Icons.calendar_month_outlined),
            const SizedBox(height:12),
            adminSelect('المشروع',projectId,[
              const MapEntry('','بدون ربط'),
              ...projects.map((p)=>MapEntry(asText(p['id']),asText(p['title']))),
            ],(v)=>update(()=>projectId=v)),
            const SizedBox(height:12),
            adminSelect('العميل',customerId,[
              const MapEntry('','بدون ربط'),
              ...clients.map((p)=>MapEntry(asText(p['id']),asText(p['full_name']))),
            ],(v)=>update(()=>customerId=v)),
            const SizedBox(height:12),
            adminInput(notes,'ملاحظات إضافية',lines:3),
            const SizedBox(height:18),
            goldButton('حفظ العملية المالية',(){
              if(!key.currentState!.validate())return;
              if((num.tryParse(amount.text)??0)<=0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content:Text('اكتب مبلغًا أكبر من صفر')));
                return;
              }
              Navigator.pop(ctx,{
                if(original!=null)'id':original['id'],
                'entry_type':type,'amount_sar':num.tryParse(amount.text)??0,
                'category':category.text.trim(),'entry_date':date,
                'project_id':projectId,'customer_id':customerId,
                'note':notes.text.trim(),
              });
            },icon:Icons.save_outlined),
          ]))),
      )),
    );
    for(final c in [category,amount,notes]){c.dispose();}
    return result;
  }

  static Future<Map<String,dynamic>?> editBlock(
      BuildContext context,List<Map<String,dynamic>> projects,
      {Map<String,dynamic>? original}) async {
    final title=TextEditingController(text:asText(original?['title']));
    final subtitle=TextEditingController(text:asText(original?['subtitle']));
    final button=TextEditingController(text:asText(original?['button_text']).isEmpty
      ?'شاهد التفاصيل':asText(original?['button_text']));
    final order=TextEditingController(text:asText(original?['display_order']).isEmpty
      ?'100':asText(original?['display_order']));
    String propertyId=asText(original?['property_id']);
    bool visible=original?['is_visible']!=false;
    final key=GlobalKey<FormState>();
    final result=await showModalBottomSheet<Map<String,dynamic>>(
      context:context,isScrollControlled:true,useSafeArea:true,
      backgroundColor:aPanel,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>Padding(
        padding:EdgeInsets.fromLTRB(18,18,18,
          MediaQuery.of(ctx).viewInsets.bottom+20),
        child:SingleChildScrollView(child:Form(key:key,
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            mainAxisSize:MainAxisSize.min,children:[
            adminTitle(original==null?'إضافة عرض أو قسم جديد':'تعديل القسم'),
            adminInput(title,'عنوان العرض',required:true),
            const SizedBox(height:12),
            adminInput(subtitle,'وصف العرض',lines:3),
            const SizedBox(height:12),
            adminInput(button,'عنوان الزر'),
            const SizedBox(height:12),
            adminInput(order,'ترتيب العرض',keyboard:TextInputType.number),
            const SizedBox(height:12),
            adminSelect('عقار مرتبط',propertyId,[
              const MapEntry('','بدون عقار'),
              ...projects.where((p)=>p['status']=='published').map((p)=>
                MapEntry(asText(p['id']),asText(p['title']))),
            ],(v)=>update(()=>propertyId=v)),
            SwitchListTile.adaptive(
              activeColor:aGold,value:visible,
              title:const Text('إظهار القسم للعملاء'),
              onChanged:(v)=>update(()=>visible=v)),
            const SizedBox(height:15),
            goldButton('حفظ القسم',(){
              if(!key.currentState!.validate())return;
              Navigator.pop(ctx,{
                if(original!=null)'id':original['id'],
                'title':title.text.trim(),'subtitle':subtitle.text.trim(),
                'button_text':button.text.trim(),
                'display_order':int.tryParse(order.text)??100,
                'property_id':propertyId,'is_visible':visible,
              });
            },icon:Icons.save_outlined),
          ]))),
      )),
    );
    for(final c in [title,subtitle,button,order]){c.dispose();}
    return result;
  }
}

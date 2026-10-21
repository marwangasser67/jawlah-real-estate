import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'theme.dart';
import 'forms.dart';
import 'settings.dart';

class JawlahAdminHub extends StatefulWidget {
  final String token;
  final Future<void> Function() onSignOut;
  final VoidCallback onSessionExpired;

  const JawlahAdminHub({super.key,required this.token,
    required this.onSignOut,required this.onSessionExpired});

  @override
  State<JawlahAdminHub> createState()=>_JawlahAdminHubState();
}
class _JawlahAdminHubState extends State<JawlahAdminHub>
    with WidgetsBindingObserver {
  final _api=const AdminApi();
  Map<String,dynamic> snapshot={};
  int tab=0;
  bool loading=true,busy=false;
  String? error;

  @override void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }
  @override void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)refresh(silent:true);
  }

  List<Map<String,dynamic>> get projects=>adminMaps(snapshot['projects']);
  List<Map<String,dynamic>> get clients=>adminMaps(snapshot['customers']);
  List<Map<String,dynamic>> get finances=>adminMaps(snapshot['finances']);
  List<Map<String,dynamic>> get images=>adminMaps(snapshot['images']);
  List<Map<String,dynamic>> get blocks=>adminMaps(snapshot['home_blocks']);
  Map<String,dynamic> get siteSettings =>
    snapshot['settings'] is Map<String,dynamic>
      ? snapshot['settings'] as Map<String,dynamic> : {};
  String projectName(dynamic id){
    for(final p in projects){
      if(p['id']==id)return asText(p['title']);
    }
    return 'بدون ربط';
  }
  String projectCover(dynamic id){
    for(final i in images){
      if(i['project_id']==id&&i['is_cover']==true)return asText(i['url']);
    }
    for(final i in images){
      if(i['project_id']==id)return asText(i['url']);
    }
    return '';
  }

  void message(String text,{bool fail=false}){
    if(!mounted)return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor:fail?const Color(0xFF4A2627):aRaised,
      content:Text(text),behavior:SnackBarBehavior.floating));
  }

  Future<void> refresh({bool silent=false}) async {
    if(!silent && mounted)setState(()=>loading=true);
    try{
      final data=await _api.getState(widget.token);
      if(!mounted)return;
      setState(() {snapshot=data;loading=false;error=null;});
    }on AdminException catch(e){
      if(e.status==401){
        widget.onSessionExpired();
        return;
      }
      if(!mounted)return;
      setState(() {loading=false;error=e.message;});
    }catch(_){
      if(!mounted)return;
      setState(() {
        loading=false;
        error='الاتصال ببيانات جولة فشل. اتأكد من الإنترنت، ومن إتاحة الموقع لخدمات التطبيق.';
      });
    }
  }

  Future<Map<String,dynamic>?> command(
      String operation,Map<String,dynamic> data,{bool site=false}) async{
    if(busy)return null;
    setState(()=>busy=true);
    try{
      final result=await _api.perform(widget.token,operation,data,site:site);
      await refresh(silent:true);
      if(mounted)message('تم الحفظ بنجاح');
      return result;
    }on AdminException catch(e){
      if(e.status==401){widget.onSessionExpired();return null;}
      message(e.message,fail:true);
    }catch(_){message('تعذر حفظ التغييرات. حاول تاني.',fail:true);}
    finally{if(mounted)setState(()=>busy=false);}
    return null;
  }

  Future<bool> confirm(String title,String details)async{
    return await showDialog<bool>(context:context,
      builder:(dialog)=>AlertDialog(
        backgroundColor:aPanel,title:Text(title),
        content:Text(details,style:const TextStyle(color:aMuted,height:1.6)),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),
            child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(dialog,true),
            child:const Text('تأكيد')),
        ]))??false;
  }

  Future<void> editProject([Map<String,dynamic>? item])async{
    final data=await AdminFormResult.editProject(context,original:item);
    if(data==null||!mounted)return;
    final result=await command('project.save',data);
    if(result!=null&&item==null&&mounted){
      final id=asText(result['id']);
      final added=projects.where((e)=>e['id']==id).firstOrNull;
      if(added!=null)openPhotos(added);
    }
  }

  Future<void> editClient([Map<String,dynamic>? item])async{
    final data=await AdminFormResult.editClient(context,projects,original:item);
    if(data!=null)await command('customer.save',data);
  }
  Future<void> editFinance([Map<String,dynamic>? item,
    String initialType='income'])async{
    final data=await AdminFormResult.editFinance(context,projects,clients,
      original:item,initialType:initialType);
    if(data!=null)await command('finance.save',data);
  }
  Future<void> editBlock([Map<String,dynamic>? item])async{
    final data=await AdminFormResult.editBlock(context,projects,original:item);
    if(data!=null)await command('block.save',data,site:true);
  }
  Future<void> deleteClient(Map<String,dynamic> item) async{
    if(!await confirm('حذف العميل',
      'هتحذف بيانات العميل من لوحة الإدارة نهائيًا.'))return;
    await command('customer.remove',{'id':item['id']});
  }
  Future<void> deleteFinance(Map<String,dynamic> item) async{
    if(!await confirm('حذف الحركة المالية',
      'الحذف هيغير حسابات الإيرادات وصافي الدخل المسجل.'))return;
    await command('finance.remove',{'id':item['id']});
  }
  Future<void> deleteBlock(Map<String,dynamic> item) async{
    if(!await confirm('حذف القسم',
      'هيختفي القسم من تطبيق العملاء بعد تحديث البيانات.'))return;
    await command('block.remove',{'id':item['id']},site:true);
  }
  Future<void> archiveProject(Map<String,dynamic> item) async{
    if(!await confirm('أرشفة العقار',
      'هيختفي من تطبيق العملاء بعد تحديث القائمة.'))return;
    await command('project.archive',{'id':item['id']});
  }

  void openPhotos(Map<String,dynamic> item) {
    Navigator.push(context,MaterialPageRoute(builder:(_)=>AdminPhotosPage(
      project:item,
      api:_api,
      token:widget.token,
      source:()=>images.where((e)=>e['project_id']==item['id']).toList(),
      onChange:()=>refresh(silent:true),
      onUnauthorized:widget.onSessionExpired,
    )));
  }

  Widget loadPage(Widget child)=>RefreshIndicator(
    color:aGold,onRefresh:()=>refresh(silent:true),child:child);

  Widget stat(String title,String value,IconData icon,Color color) =>
    Container(
      width:170,padding:const EdgeInsets.all(15),
      decoration:BoxDecoration(color:aPanel,border:Border.all(color:aLine),
        borderRadius:BorderRadius.circular(17)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(icon,color:color,size:26),
        const SizedBox(height:10),
        Text(title,style:const TextStyle(color:aMuted,fontSize:12)),
        const SizedBox(height:4),
        Text(value,style:TextStyle(color:color,
          fontSize:18,fontWeight:FontWeight.w900),
          maxLines:2,overflow:TextOverflow.ellipsis),
      ]));

  Widget homePage(){
    final income=finances.where((e)=>e['entry_type']=='income')
      .fold<double>(0,(sum,e)=>sum+asNumber(e['amount_sar']).toDouble());
    final expense=finances.where((e)=>e['entry_type']=='expense')
      .fold<double>(0,(sum,e)=>sum+asNumber(e['amount_sar']).toDouble());
    final active=clients.where((e)=>!['won','lost'].contains(e['stage'])).length;
    final published=projects.where((e)=>e['status']=='published').length;
    return loadPage(ListView(
      key:const PageStorageKey('native-home'),
      padding:const EdgeInsets.fromLTRB(17,12,17,28),children:[
        Row(children:[
          Image.asset('assets/branding/jawlah_launcher.png',width:63,height:63),
          const SizedBox(width:11),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text('لوحة تحكم جولة',style:TextStyle(
                fontSize:23,fontWeight:FontWeight.w900)),
              Text('كل أعمالك في مكان واحد',
                style:TextStyle(color:aGold,fontSize:12)),
            ])),
        ]),
        const SizedBox(height:18),
        adminTitle('نظرة عامة',subtitle:'الأرقام من قيودك المسجلة في قاعدة البيانات'),
        Wrap(spacing:10,runSpacing:10,children:[
          stat('إجمالي الإيرادات',riyal(income),
            Icons.trending_up,aGreen),
          stat('إجمالي المصروفات',riyal(expense),
            Icons.trending_down,aRed),
          stat('صافي الحركة',riyal(income-expense),
            Icons.account_balance_wallet_outlined,aGold),
          stat('المشاريع المنشورة',published.toString(),
            Icons.apartment_outlined,aGold),
          stat('العملاء قيد المتابعة',active.toString(),
            Icons.people_outline,aGold),
        ]),
        const SizedBox(height:22),
        panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            const Text('خطوات سريعة',style:TextStyle(
              fontSize:18,fontWeight:FontWeight.bold)),
            const SizedBox(height:15),
            outlinedAction('أضف مشروع وصور حقيقية',()=>editProject(),
              icon:Icons.add_home_work_outlined),
            const SizedBox(height:9),
            outlinedAction('أضف عميل جديد',()=>editClient(),
              icon:Icons.person_add_alt_outlined),
            const SizedBox(height:9),
            outlinedAction('سجّل إيراد أو مصروف',()=>editFinance(),
              icon:Icons.add_chart_rounded),
            const SizedBox(height:9),
            outlinedAction('عدّل تطبيق العملاء',
              ()=>setState(()=>tab=4),icon:Icons.edit_note),
          ])),
        const SizedBox(height:18),
        panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            const Text('حالة العملاء',style:TextStyle(
              fontSize:18,fontWeight:FontWeight.bold)),
            const SizedBox(height:15),
            for(final stage in ['new','contacted','visit','negotiating','won','lost'])
              Padding(padding:const EdgeInsets.only(bottom:13),
                child:Row(children:[
                  Expanded(child:Text(statusTitle(stage),
                    style:const TextStyle(color:aMuted))),
                  Text(clients.where((e)=>e['stage']==stage).length.toString(),
                    style:const TextStyle(color:aGold,
                      fontWeight:FontWeight.w900)),
                ])),
          ])),
        const SizedBox(height:15),
        const Text('ملاحظة: صافي الحركة المسجلة ليس صافي الربح المحاسبي النهائي إلا بعد تسجيل كل التكاليف والضرائب.',
          style:TextStyle(color:aMuted,fontSize:11,height:1.7)),
      ]));
  }

  Widget smallCover(String url,{double size=77})=>
    ClipRRect(borderRadius:BorderRadius.circular(11),
      child:url.isEmpty?
        Container(width:size,height:size,color:aRaised,
          child:const Icon(Icons.home_work_outlined,color:aGold,size:29)):
        Image.network(url,width:size,height:size,fit:BoxFit.cover,
          errorBuilder:(_,__,___)=>Container(width:size,height:size,color:aRaised,
            child:const Icon(Icons.photo_outlined,color:aGold))));

  Widget projectPage(){
    return loadPage(ListView(
      key:const PageStorageKey('native-projects'),
      padding:const EdgeInsets.fromLTRB(15,14,15,90),children:[
        adminTitle('العقارات والمشاريع',
          subtitle:'إضافة وتعديل العقارات والأسعار والصور'),
        goldButton('إضافة عقار جديد',()=>editProject(),
          icon:Icons.add_circle_outline),
        const SizedBox(height:15),
        if(projects.isEmpty)
          adminEmpty(Icons.home_work_outlined,
            'لا توجد عقارات حتى الآن','ابدأ بإضافة مشروع جديد وارفع صوره')
        else for(final item in projects) ...[
          panel(child:Column(children:[
            Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              smallCover(projectCover(item['id']),size:85),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(asText(item['title']),maxLines:2,
                    overflow:TextOverflow.ellipsis,
                    style:const TextStyle(
                      fontWeight:FontWeight.w900,fontSize:16)),
                  const SizedBox(height:4),
                  Text(asText(item['city'])+' • '+asText(item['district']),
                    style:const TextStyle(color:aMuted,fontSize:11)),
                  const SizedBox(height:6),
                  Text(riyal(item['price_sar']),
                    style:const TextStyle(color:aGold,
                      fontWeight:FontWeight.w900)),
                  Text(statusTitle(asText(item['status'])),
                    style:TextStyle(
                      color:item['status']=='published'?aGreen:aMuted,fontSize:11)),
                ])),
            ]),
            const SizedBox(height:14),
            Row(children:[
              Expanded(child:outlinedAction('تعديل',()=>editProject(item),
                icon:Icons.edit_outlined)),
              const SizedBox(width:8),
              Expanded(child:outlinedAction('الصور',
                ()=>openPhotos(item),icon:Icons.collections_outlined)),
            ]),
            if(item['status']!='archived')Align(
              alignment:Alignment.centerLeft,
              child:TextButton(
                onPressed:()=>archiveProject(item),
                child:const Text('أرشفة العقار',
                  style:TextStyle(color:aMuted,fontSize:12))))
          ])),
          const SizedBox(height:11),
        ]
      ]));
  }

  Widget clientPage(){
    return loadPage(ListView(
      key:const PageStorageKey('native-clients'),
      padding:const EdgeInsets.fromLTRB(15,14,15,88),children:[
        adminTitle('متابعة العملاء',
          subtitle:'مراحل البيع والملاحظات محفوظة في لوحة جولة الخاصة'),
        goldButton('إضافة عميل جديد',()=>editClient(),
          icon:Icons.person_add_alt_outlined),
        const SizedBox(height:17),
        if(clients.isEmpty)
          adminEmpty(Icons.groups_2_outlined,'لسه مفيش عملاء',
            'سجّل أول عميل هنا واعرف آخر متابعة لكل عميل')
        else for(final c in clients) ...[
          panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[
            Row(children:[
              CircleAvatar(backgroundColor:const Color(0xFF403420),
                child:Text(asText(c['full_name']).isEmpty?'ع':
                  asText(c['full_name']).substring(0,1),
                  style:const TextStyle(color:aGold))),
              const SizedBox(width:11),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(asText(c['full_name']),style:const TextStyle(
                    fontSize:16,fontWeight:FontWeight.bold)),
                  Text(asText(c['phone']),textDirection:TextDirection.ltr,
                    style:const TextStyle(fontSize:12,color:aMuted)),
                ])),
              Chip(
                label:Text(statusTitle(asText(c['stage'])),
                  style:const TextStyle(fontSize:11)),
                backgroundColor:aRaised,side:const BorderSide(color:aGoldDeep)),
            ]),
            const SizedBox(height:8),
            Text('العقار: '+projectName(c['project_id']),
              style:const TextStyle(color:aMuted,fontSize:12)),
            if(asText(c['notes']).isNotEmpty) ...[
              const SizedBox(height:8),
              Text(asText(c['notes']),maxLines:3,
                style:const TextStyle(color:aMuted,fontSize:12)),
            ],
            const SizedBox(height:12),
            Row(children:[
              Expanded(child:outlinedAction('تعديل بيانات العميل',
                ()=>editClient(c),icon:Icons.edit_outlined)),
              IconButton(onPressed:()=>deleteClient(c),
                icon:const Icon(Icons.delete_outline,color:aRed)),
            ])
          ])),
          const SizedBox(height:11),
        ],
      ]));
  }

  Widget financePage(){
    final income=finances.where((e)=>e['entry_type']=='income')
      .fold<double>(0,(s,e)=>s+asNumber(e['amount_sar']).toDouble());
    final expense=finances.where((e)=>e['entry_type']=='expense')
      .fold<double>(0,(s,e)=>s+asNumber(e['amount_sar']).toDouble());
    return loadPage(ListView(
      key:const PageStorageKey('native-finance'),
      padding:const EdgeInsets.fromLTRB(15,14,15,88),children:[
        adminTitle('الإيرادات والمصروفات',subtitle:'دفتر مالي بالريال السعودي'),
        Wrap(spacing:8,runSpacing:9,children:[
          stat('الإيرادات',riyal(income),Icons.arrow_upward,aGreen),
          stat('المصروفات',riyal(expense),Icons.arrow_downward,aRed),
          stat('صافي الحركة',riyal(income-expense),
            Icons.calculate_outlined,aGold),
        ]),
        const SizedBox(height:17),
        Row(children:[
          Expanded(child:outlinedAction('مصروف',()=>editFinance(null,'expense'),
            icon:Icons.remove_circle_outline)),
          const SizedBox(width:10),
          Expanded(child:goldButton('إيراد',()=>editFinance(null,'income'),
            icon:Icons.add_circle_outline)),
        ]),
        const SizedBox(height:16),
        if(finances.isEmpty)
          adminEmpty(Icons.account_balance_wallet_outlined,'مفيش قيود مالية',
            'سجّل أول إيراد أو مصروف عشان حساباتك تظهر هنا')
        else for(final f in finances) ...[
          panel(child:Row(children:[
            CircleAvatar(backgroundColor:aRaised,child:Icon(
              f['entry_type']=='income'?Icons.south_west:Icons.north_east,
              color:f['entry_type']=='income'?aGreen:aRed)),
            const SizedBox(width:11),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(asText(f['category']),style:const TextStyle(
                  fontSize:15,fontWeight:FontWeight.bold)),
                Text(shortDate(f['entry_date'])+' • '+projectName(f['project_id']),
                  style:const TextStyle(fontSize:11,color:aMuted)),
                Text(riyal(f['amount_sar']),style:TextStyle(
                  color:f['entry_type']=='income'?aGreen:aRed,
                  fontWeight:FontWeight.w900,fontSize:15)),
              ])),
            PopupMenuButton<String>(
              onSelected:(value){
                if(value=='edit')editFinance(f);
                if(value=='remove')deleteFinance(f);
              },
              itemBuilder:(_)=>const [
                PopupMenuItem(value:'edit',child:Text('تعديل')),
                PopupMenuItem(value:'remove',child:Text('حذف القيد')),
              ],
            ),
          ])),
          const SizedBox(height:10),
        ],
        const SizedBox(height:15),
        const Text('الربح المحاسبي الفعلي قد يختلف عن صافي التدفق، حسب المصروفات غير المسجلة والضرائب والالتزامات.',
          style:TextStyle(color:aMuted,fontSize:11,height:1.7)),
      ]));
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor:aBg,
      appBar:AppBar(
        leading:Padding(padding:const EdgeInsets.all(6),
          child:Image.asset('assets/branding/jawlah_launcher.png')),
        title:const Text('جولة | الإدارة'),
        actions:[
          IconButton(tooltip:'تحديث',onPressed:busy?null:()=>refresh(),
            icon:const Icon(Icons.refresh_rounded,color:aGold)),
          PopupMenuButton<String>(
            onSelected:(value)async{
              if(value=='logout' &&
                await confirm('تسجيل خروج الإدارة',
                  'لن تقدر تدخل للبيانات المحمية إلا لما تربط الجهاز من جديد.')){
                await widget.onSignOut();
              }
            },
            itemBuilder:(_)=>const [
              PopupMenuItem(value:'logout',
                child:Text('تسجيل الخروج وإلغاء ربط الجهاز')),
            ]),
        ]),
      body:SafeArea(child:Stack(children:[
        if(error!=null && snapshot.isEmpty)
          adminEmpty(Icons.wifi_off_rounded,'تعذر الاتصال بالخادم',error!)
        else IndexedStack(index:tab,children:[
          homePage(),projectPage(),clientPage(),financePage(),
          AdminSiteSettings(
            key:ValueKey(asText(siteSettings['updated_at'])),
            settings:siteSettings,projects:projects,blocks:blocks,
            onSave:(values)async{
              final result=await command('settings.save',values,site:true);
              return result!=null;
            },
            onAdd:()=>editBlock(),
            onEdit:(item)=>editBlock(item),
            onDelete:(item)=>deleteBlock(item),
          ),
        ]),
        if(loading)
          const Positioned.fill(child:ColoredBox(
            color:Color(0xCC0C1015),
            child:Center(child:CircularProgressIndicator(color:aGold)))),
        if(busy)
          const Positioned(bottom:0,left:0,right:0,
            child:LinearProgressIndicator(color:aGold)),
      ])),
      bottomNavigationBar:NavigationBar(
        height:70,backgroundColor:aPanel,
        indicatorColor:const Color(0xFF473822),
        selectedIndex:tab,
        onDestinationSelected:(index)=>setState(()=>tab=index),
        labelTextStyle:WidgetStateProperty.resolveWith((states)=>
          TextStyle(fontSize:10,
            color:states.contains(WidgetState.selected)?aGold:aMuted)),
        destinations:const [
          NavigationDestination(icon:Icon(Icons.grid_view_outlined),
            selectedIcon:Icon(Icons.grid_view_rounded,color:aGold),
            label:'الرئيسية'),
          NavigationDestination(icon:Icon(Icons.home_work_outlined),
            selectedIcon:Icon(Icons.home_work,color:aGold),label:'العقارات'),
          NavigationDestination(icon:Icon(Icons.people_outline),
            selectedIcon:Icon(Icons.people,color:aGold),label:'العملاء'),
          NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),
            selectedIcon:Icon(Icons.account_balance_wallet,color:aGold),label:'المالية'),
          NavigationDestination(icon:Icon(Icons.tune_outlined),
            selectedIcon:Icon(Icons.tune,color:aGold),label:'التطبيق'),
        ]),
    );
  }
}

class AdminPhotosPage extends StatefulWidget{
  final Map<String,dynamic> project;
  final AdminApi api;
  final String token;
  final List<Map<String,dynamic>> Function() source;
  final Future<void> Function() onChange;
  final VoidCallback onUnauthorized;
  const AdminPhotosPage({super.key,required this.project,required this.api,
    required this.token,required this.source,required this.onChange,
    required this.onUnauthorized});

  @override State<AdminPhotosPage> createState()=>_AdminPhotosPageState();
}
class _AdminPhotosPageState extends State<AdminPhotosPage>{
  bool busy=false;
  void notify(String message){
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
  }
  Future<void> upload()async {
    final file=await ImagePicker().pickImage(
      source:ImageSource.gallery,imageQuality:78,maxWidth:1500,
      requestFullMetadata:false);
    if(file==null)return;
    setState(()=>busy=true);
    try{
      await widget.api.uploadPhoto(
        token:widget.token,projectId:asText(widget.project['id']),file:file);
      await widget.onChange();
      if(mounted)setState((){});
      notify('تم رفع الصورة إلى مشروعك.');
    }on AdminException catch(e){
      if(e.status==401)widget.onUnauthorized();
      notify(e.message);
    }catch(_){notify('تعذر رفع الصورة. اختر JPG أو PNG بحجم أصغر.');}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> change(String action,Map<String,dynamic> item)async{
    if(action=='image.remove'){
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('حذف الصورة'),
        content:const Text('تأكيد الحذف نهائيًا من المشروع؟'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('إلغاء')),
          TextButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('حذف')),
        ]));
      if(ok!=true)return;
    }
    setState(()=>busy=true);
    try{
      await widget.api.perform(widget.token,action,{'id':item['id']});
      await widget.onChange();
      if(mounted)setState((){});
      notify('تم تحديث صور المشروع.');
    }on AdminException catch(e){
      if(e.status==401)widget.onUnauthorized();
      notify(e.message);
    }catch(_){notify('فشل تحديث الصورة.');}
    finally{if(mounted)setState(()=>busy=false);}
  }

  @override Widget build(BuildContext context){
    final files=widget.source();
    return Scaffold(
      backgroundColor:aBg,
      appBar:AppBar(title:Text('صور: '+asText(widget.project['title']))),
      body:SafeArea(child:ListView(
        padding:const EdgeInsets.all(16),children:[
          adminTitle('صور المشروع الحقيقية',
            subtitle:'حتى 30 صورة. اضغط النجمة لاختيار الغلاف.'),
          goldButton(busy?'جارٍ العمل...':'رفع صورة من الموبايل',
            busy?null:upload,icon:Icons.add_photo_alternate_outlined),
          const SizedBox(height:15),
          if(files.isEmpty)
            adminEmpty(Icons.photo_library_outlined,'لم ترفع صورًا بعد',
              'اختر صور المشروع من معرض الموبايل')
          else GridView.builder(
            shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
            gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:2,mainAxisSpacing:11,
              crossAxisSpacing:11,childAspectRatio:.90),
            itemCount:files.length,itemBuilder:(_,index){
              final img=files[index],url=asText(img['url']);
              return Container(
                clipBehavior:Clip.antiAlias,
                decoration:BoxDecoration(color:aPanel,
                  border:Border.all(color:aLine),
                  borderRadius:BorderRadius.circular(13)),
                child:Column(children:[
                  Expanded(child:url.isEmpty?
                    const Center(child:Icon(Icons.photo,color:aGold)):
                    Image.network(url,width:double.infinity,
                      fit:BoxFit.cover,
                      errorBuilder:(_,__,___)=>const Center(
                        child:Icon(Icons.broken_image_outlined,color:aGold)))),
                  Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,
                    children:[
                    IconButton(
                      tooltip:'اجعلها صورة الغلاف',
                      onPressed:busy?null:()=>change('image.cover',img),
                      icon:Icon(img['is_cover']==true
                        ?Icons.star:Icons.star_border,
                        color:aGold)),
                    IconButton(
                      tooltip:'حذف الصورة',
                      onPressed:busy?null:()=>change('image.remove',img),
                      icon:const Icon(Icons.delete_outline,color:aRed)),
                  ]),
                ]),
              );
            }),
          const SizedBox(height:16),
          const Text('هذه الصور ستظهر للعملاء إذا كانت حالة العقار «جاهز للعرض»، بعد تفعيل إتاحة الكتالوج.',
            style:TextStyle(color:aMuted,fontSize:12,height:1.7)),
        ])),
      ),
    );
  }
}

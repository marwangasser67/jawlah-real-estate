import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin/api.dart';
import 'admin/dashboard.dart';
import 'admin/theme.dart';

void main(){
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JawlahAdminApp());
}

class JawlahAdminApp extends StatelessWidget {
  const JawlahAdminApp({super.key});

  @override Widget build(BuildContext context)=>MaterialApp(
    title:'جولة | الإدارة',
    debugShowCheckedModeBanner:false,
    theme:adminTheme(),
    home:const Directionality(textDirection:TextDirection.rtl,
      child:AdminAuthGate()),
  );
}

class AdminAuthGate extends StatefulWidget{
  const AdminAuthGate({super.key});
  @override State<AdminAuthGate> createState()=>_AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate>{
  static const _storage=FlutterSecureStorage(
    aOptions:AndroidOptions(encryptedSharedPreferences:true));
  static const _tokenKey='jawlah_admin_native_session';
  static const _stateKey='jawlah_admin_pending_state';
  static const _verifierKey='jawlah_admin_pending_verifier';

  final _api=const AdminApi();
  final _links=AppLinks();
  final _manual=TextEditingController();
  StreamSubscription<Uri>? _subscription;
  String? _token,_pairState,_verifier,_error;
  bool _loading=true,_pairing=false,_redeeming=false,_showManual=false;

  @override void initState(){
    super.initState();
    _subscription=_links.uriLinkStream.listen(
      _acceptLink,onError:(_){if(mounted)setState(()=>
        _error='تعذر فتح رابط الربط. يمكن إدخال الكود يدويًا.');});
    _initialize();
  }
  Future<void> _initialize()async{
    final token=await _storage.read(key:_tokenKey);
    final verifier=await _storage.read(key:_verifierKey);
    final state=await _storage.read(key:_stateKey);
    if(!mounted)return;
    setState((){
      _token=token;
      _verifier=verifier;
      _pairState=state;
      _loading=false;
    });
    try{
      final initial=await _links.getInitialLink();
      if(initial!=null)_acceptLink(initial);
    }catch(_){}
  }
  @override void dispose(){
    _subscription?.cancel();
    _manual.dispose();
    super.dispose();
  }
  String _random(int size){
    final random=Random.secure();
    return base64Url.encode(List<int>.generate(size,(_)=>random.nextInt(256)))
      .replaceAll('=','');
  }

  Future<void> _startPairing()async{
    if(_pairing)return;
    setState((){_pairing=true;_error=null;});
    try{
      final verifier=_random(48);
      final state=_random(24);
      final hash=sha256.convert(utf8.encode(verifier)).toString();
      await _storage.write(key:_verifierKey,value:verifier);
      await _storage.write(key:_stateKey,value:state);
      _verifier=verifier;
      _pairState=state;
      final url=Uri.parse(jawlahService + '/device-connect').replace(
        queryParameters:{'challenge':hash,'state':state});
      final opened=await launchUrl(url,mode:LaunchMode.externalApplication);
      if(!opened){
        throw Exception('متصفح الأمان لم يفتح. اتأكد إن Chrome مثبت.');
      }
    }catch(e){
      if(mounted)setState(()=>_error=
        'تعذر بدء ربط الجهاز. افتح Chrome وتحقق من الإنترنت، ثم حاول مجددًا.');
    }finally{
      if(mounted)setState(()=>_pairing=false);
    }
  }

  Future<void> _acceptLink(Uri uri)async{
    if(uri.scheme!='jawlahadmin'||uri.host!='activate')return;
    final code=uri.queryParameters['code']??'';
    final state=uri.queryParameters['state']??'';
    await _activate(code,state);
  }

  Future<void> _activate(String code,String state)async{
    if(_redeeming)return;
    setState((){_redeeming=true;_error=null;});
    try{
      final expected=_pairState??await _storage.read(key:_stateKey);
      final verifier=_verifier??await _storage.read(key:_verifierKey);
      if(expected==null||verifier==null||
          state!=expected||code.length!=64){
        throw const AdminException(400,
          'رابط الربط مختلف عن طلب هذا الجهاز. ابدأ ربط جديد.');
      }
      final result=await _api.activate(
        code:code,verifier:verifier,state:state);
      final newToken=(result['token']??'').toString();
      if(newToken.length!=64)throw const AdminException(502,
        'لم تصل بيانات جلسة المدير من الخادم.');
      await _storage.write(key:_tokenKey,value:newToken);
      await _storage.delete(key:_verifierKey);
      await _storage.delete(key:_stateKey);
      if(!mounted)return;
      setState((){
        _token=newToken;
        _verifier=null;_pairState=null;
        _manual.clear();
      });
    }on AdminException catch(e){
      if(mounted)setState(()=>_error=e.message);
    }catch(_){
      if(mounted)setState(()=>_error=
        'الربط لم يكتمل. تأكد من الإنترنت وإتاحة خادم الإدارة، ثم جرّب مرة أخرى.');
    }finally{
      if(mounted)setState(()=>_redeeming=false);
    }
  }

  Future<void> _manualActivation()async{
    final value=_manual.text.trim();
    final uri=Uri.tryParse(value);
    String code=value;
    if(uri!=null&&uri.scheme=='jawlahadmin'){
      code=uri.queryParameters['code']??'';
    }
    final state=_pairState??await _storage.read(key:_stateKey);
    await _activate(code,state??'');
  }

  Future<void> _signOut()async{
    final old=_token;
    await _storage.delete(key:_tokenKey);
    await _storage.delete(key:_verifierKey);
    await _storage.delete(key:_stateKey);
    if(old!=null)await _api.signOut(old);
    if(mounted)setState((){
      _token=null;_verifier=null;_pairState=null;
      _error=null;
    });
  }
  void _expired()async{
    await _storage.delete(key:_tokenKey);
    if(mounted)setState((){
      _token=null;
      _error='جلسة المدير انتهت. اربط الموبايل بحساب جولة من جديد.';
    });
  }

  @override Widget build(BuildContext context){
    if(_loading)return const Scaffold(
      body:Center(child:CircularProgressIndicator(color:aGold)));
    if(_token!=null)return JawlahAdminHub(
      token:_token!,onSignOut:_signOut,onSessionExpired:_expired);
    return Scaffold(backgroundColor:aBg,body:SafeArea(
      child:ListView(
        padding:const EdgeInsets.fromLTRB(23,32,23,36),children:[
          Center(child:Container(
            height:118,width:118,padding:const EdgeInsets.all(8),
            decoration:BoxDecoration(
              color:aPanel,borderRadius:BorderRadius.circular(28),
              border:Border.all(color:aGold)),
            child:Image.asset('assets/branding/jawlah_launcher.png'))),
          const SizedBox(height:22),
          const Text('جولة | الإدارة',textAlign:TextAlign.center,
            style:TextStyle(color:aGold,fontSize:30,
              fontWeight:FontWeight.w900)),
          const SizedBox(height:5),
          const Text('تطبيق إدارة كامل على موبايلك',
            textAlign:TextAlign.center,
            style:TextStyle(fontSize:15,color:aMuted)),
          const SizedBox(height:28),
          panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              const Text('إدارة حقيقية من داخل التطبيق',
                style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
              const SizedBox(height:12),
              const Row(children:[
                Icon(Icons.home_work_outlined,color:aGold),
                SizedBox(width:12),
                Expanded(child:Text('إضافة وتعديل العقارات والأسعار والصور')),
              ]),
              const SizedBox(height:16),
              const Row(children:[
                Icon(Icons.people_outline,color:aGold),
                SizedBox(width:12),
                Expanded(child:Text('إدارة العملاء والصفقات والمعاينات')),
              ]),
              const SizedBox(height:16),
              const Row(children:[
                Icon(Icons.wallet_outlined,color:aGold),
                SizedBox(width:12),
                Expanded(child:Text('تسجيل الإيرادات والمصروفات والأرباح')),
              ]),
              const SizedBox(height:16),
              const Row(children:[
                Icon(Icons.tune_outlined,color:aGold),
                SizedBox(width:12),
                Expanded(child:Text('التحكم في واجهة تطبيق العملاء')),
              ]),
            ])),
          const SizedBox(height:22),
          goldButton(_pairing?'جارٍ فتح تسجيل الدخول...':
            'ربط الجهاز بحساب المدير',
            (_pairing||_redeeming)?null:_startPairing,
            icon:Icons.verified_user_outlined),
          const SizedBox(height:10),
          const Text('لأمان بيانات عملائك، هتوافق على ربط الموبايل بحساب المدير مرة واحدة في المتصفح. بعدها هتستخدم شاشات الإدارة هنا بدون Chrome، لحد انتهاء الجلسة أو إلغائها.',
            style:TextStyle(fontSize:12,color:aMuted,height:1.75),
            textAlign:TextAlign.center),
          const SizedBox(height:13),
          if(_pairState!=null)
            TextButton.icon(onPressed:()=>
              setState(()=>_showManual=!_showManual),
              icon:const Icon(Icons.key_outlined,color:aGold),
              label:const Text('عندي كود ربط من المتصفح',
                style:TextStyle(color:aGold))),
          if(_showManual&&_pairState!=null) ...[
            adminInput(_manual,'الصق كود الربط'),
            const SizedBox(height:10),
            goldButton(_redeeming?'جارٍ التحقق...':'تفعيل الكود',
              _redeeming?null:_manualActivation,icon:Icons.check_circle),
          ],
          if(_error!=null) ...[
            const SizedBox(height:15),
            panel(child:Text(_error!,style:const TextStyle(
              color:aRed,fontSize:12,height:1.7))),
          ],
          const SizedBox(height:22),
          const Text('مهم: المشروع الحالي على Hatchable ما زال Personal؛ لازم إتاحة واجهات التطبيق من إعدادات النشر عشان بيانات الإدارة تتصل من الموبايل.',
            style:TextStyle(color:aMuted,fontSize:11,height:1.6),
            textAlign:TextAlign.center),
        ])));
  }
}

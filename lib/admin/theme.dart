import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api.dart';

const aBg = Color(0xFF0C1015);
const aPanel = Color(0xFF181D25);
const aRaised = Color(0xFF252B35);
const aLine = Color(0xFF383F49);
const aGold = Color(0xFFDFBD80);
const aGoldDeep = Color(0xFF97754B);
const aWhite = Color(0xFFF8F5EF);
const aMuted = Color(0xFFB0B8C4);
const aGreen = Color(0xFF80D4AE);
const aRed = Color(0xFFF2A6A0);

ThemeData adminTheme() {
  final text = GoogleFonts.cairoTextTheme(
    ThemeData(brightness: Brightness.dark).textTheme);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: aBg,
    textTheme: text.apply(bodyColor: aWhite, displayColor: aWhite),
    colorScheme: ColorScheme.fromSeed(
      seedColor: aGold, brightness: Brightness.dark,
      surface: aPanel, primary: aGold, onPrimary: aBg),
    appBarTheme: AppBarTheme(
      backgroundColor: aBg,
      foregroundColor: aWhite,
      titleTextStyle: GoogleFonts.cairo(
        color: aGold, fontSize: 20, fontWeight: FontWeight.w900)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: aRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      labelStyle: const TextStyle(color: aMuted),
      hintStyle: const TextStyle(color: aMuted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: aLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: aLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: aGold)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: aRaised, contentTextStyle: TextStyle(color: aWhite)),
    dividerColor: aLine,
  );
}

String riyal(dynamic input) {
  final value = asNumber(input);
  final digits = value.round().toString();
  final display = digits.replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',');
  return display + ' ر.س';
}
String shortDate(dynamic input) {
  final s=asText(input);
  if(s.length>=10)return s.substring(0,10);
  return s;
}
String statusTitle(String status) {
  const m={'draft':'مسودة','published':'جاهز للعرض','archived':'مؤرشف',
    'new':'جديد','contacted':'تم التواصل','visit':'معاينة',
    'negotiating':'تفاوض','won':'تم الاتفاق','lost':'لم يكتمل'};
  return m[status]??status;
}

Widget goldButton(String title, VoidCallback? handler,
    {IconData icon=Icons.check_rounded}) => SizedBox(
  width: double.infinity, height: 49,
  child: FilledButton.icon(
    onPressed: handler,
    icon: Icon(icon, size: 20),
    label: Text(title, maxLines:1,overflow:TextOverflow.ellipsis,
      style:const TextStyle(fontWeight:FontWeight.w900)),
    style: FilledButton.styleFrom(
      backgroundColor:aGold,foregroundColor:aBg,
      shape:RoundedRectangleBorder(
        borderRadius:BorderRadius.circular(13)))));

Widget outlinedAction(String title, VoidCallback? handler,
    {IconData icon=Icons.edit_outlined}) => SizedBox(
  width: double.infinity, height: 46,
  child: OutlinedButton.icon(
    onPressed: handler, icon:Icon(icon,size:18),label:Text(title),
    style: OutlinedButton.styleFrom(
      foregroundColor:aGold, side:const BorderSide(color:aGoldDeep),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)))));

Widget panel({required Widget child, EdgeInsetsGeometry? padding}) =>
  Container(width:double.infinity,
    padding:padding??const EdgeInsets.all(17),
    decoration:BoxDecoration(
      color:aPanel,border:Border.all(color:aLine),
      borderRadius:BorderRadius.circular(17)),
    child:child);

Widget adminTitle(String title, {String? subtitle})=>Padding(
  padding:const EdgeInsets.only(bottom:18),
  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(
      fontSize:25,fontWeight:FontWeight.w900)),
    if(subtitle!=null) ...[
      const SizedBox(height:5),
      Text(subtitle,style:const TextStyle(color:aMuted,fontSize:12)),
    ]
  ]));

Widget adminEmpty(IconData icon, String title,String subtitle)=>Center(
  child:Padding(padding:const EdgeInsets.symmetric(vertical:48,horizontal:19),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Icon(icon,color:aGold,size:60),
      const SizedBox(height:14),
      Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold),
        textAlign:TextAlign.center),
      const SizedBox(height:7),
      Text(subtitle,textAlign:TextAlign.center,
        style:const TextStyle(color:aMuted,height:1.6)),
    ])));

Widget adminInput(TextEditingController controller,String label,
    {TextInputType? keyboard,int lines=1, bool required=false})=>
  TextFormField(controller:controller,maxLines:lines,keyboardType:keyboard,
    validator:required?(v)=>(v==null||v.trim().isEmpty)?'الخانة دي مطلوبة':null:null,
    decoration:InputDecoration(labelText:label));

Widget adminSelect(String title,String current,List<MapEntry<String,String>> choices,
    ValueChanged<String> onChange)=>DropdownButtonFormField<String>(
  value:choices.any((e)=>e.key==current)?current:(choices.isEmpty?null:choices.first.key),
  isExpanded:true,dropdownColor:aRaised,
  decoration:InputDecoration(labelText:title),
  items:choices.map((e)=>DropdownMenuItem<String>(value:e.key,
    child:Text(e.value,maxLines:1,overflow:TextOverflow.ellipsis))).toList(),
  onChanged:(v){if(v!=null)onChange(v);});

List<MapEntry<String,String>> staticOptions(Map<String,String> map)=>
  map.entries.toList();

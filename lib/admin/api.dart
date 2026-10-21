import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

const String jawlahService = 'https://jawlah-real-estate-5sz9.hatchable.site';
const String jawlahMobileApi = jawlahService + '/api/mobile';

class AdminException implements Exception {
  final int status;
  final String message;
  const AdminException(this.status, this.message);
  @override
  String toString() => message;
}

class AdminApi {
  const AdminApi();

  Future<Map<String, dynamic>> _unwrap(http.Response response) async {
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        map = decoded;
      } else {
        throw const FormatException();
      }
    } catch (_) {
      throw AdminException(response.statusCode,
        'تعذر الاتصال بالخادم. تحقق من الإنترنت وإعدادات إتاحة مشروع جولة.');
    }
    if (response.statusCode == 401 &&
        (map['error'] == 'login_required' ||
          map['error'] == 'unauthorized' && map['login_url'] != null ||
          map['type'] == 'unauthenticated')) {
      throw const AdminException(428,
        'استضافة جولة في Hatchable على وضع Personal. لازم مالك المشروع يفتح Settings > Sharing ويتيح الوصول العام للكتالوج والواجهات قبل استخدام التطبيق. بيانات العملاء والمالية مازالت محمية برمز المدير.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminException(response.statusCode, (map['error'] ??
        map['message'] ?? 'حدث خطأ. حاول مرة أخرى.').toString());
    }
    return map;
  }

  Map<String, String> headers(String token, {bool json = true}) => {
    'Authorization': 'Bearer ' + token,
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> getState(String token) async {
    final response = await http.get(Uri.parse(jawlahMobileApi + '/state'),
      headers: headers(token)).timeout(const Duration(seconds: 24));
    return _unwrap(response);
  }

  Future<Map<String, dynamic>> perform(String token, String action,
      Map<String, dynamic> data, {bool site = false}) async {
    final response = await http.post(
      Uri.parse(jawlahMobileApi + (site ? '/site' : '/manage')),
      headers: headers(token),
      body: jsonEncode({'action': action, 'data': data}),
    ).timeout(const Duration(seconds: 25));
    return _unwrap(response);
  }

  Future<Map<String, dynamic>> activate({
    required String code,
    required String verifier,
    required String state,
  }) async {
    final response = await http.post(
      Uri.parse(jawlahMobileApi + '/activate'),
      headers: {'Accept':'application/json', 'Content-Type':'application/json'},
      body: jsonEncode({'code':code,'verifier':verifier,'state':state}),
    ).timeout(const Duration(seconds: 25));
    return _unwrap(response);
  }

  Future<void> signOut(String token) async {
    try {
      await http.post(Uri.parse(jawlahMobileApi + '/sign-out'),
        headers: headers(token)).timeout(const Duration(seconds: 12));
    } catch (_) {
      // Local token is wiped even when revocation is unavailable.
    }
  }

  Future<Map<String, dynamic>> uploadPhoto({
    required String token,
    required String projectId,
    required XFile file,
  }) async {
    final length = await file.length();
    if (length > 4 * 1024 * 1024) {
      throw const AdminException(413,
        'حجم الصورة أكثر من 4 ميجابايت. اختر صورة أصغر.');
    }
    final extension=file.name.toLowerCase().split('.').last;
    final mime = extension == 'png' ? MediaType('image','png') :
      extension == 'webp' ? MediaType('image','webp') :
      MediaType('image','jpeg');
    if (!['png','jpg','jpeg','webp'].contains(extension)) {
      throw const AdminException(415,'مسموح فقط بصور JPG وPNG وWebP.');
    }
    final request=http.MultipartRequest('POST',
      Uri.parse(jawlahMobileApi + '/upload'));
    request.headers.addAll(headers(token,json:false));
    request.fields['project_id']=projectId;
    request.files.add(http.MultipartFile.fromBytes(
      'file',await file.readAsBytes(),filename:file.name,contentType:mime));
    final streamed=await request.send().timeout(const Duration(seconds: 55));
    final response=await http.Response.fromStream(streamed);
    return _unwrap(response);
  }
}

List<Map<String, dynamic>> adminMaps(dynamic input) {
  if (input is! List) return [];
  return input.whereType<Map<String, dynamic>>().toList();
}
String asText(dynamic input) => (input ?? '').toString();
num asNumber(dynamic input) => num.tryParse(asText(input)) ?? 0;

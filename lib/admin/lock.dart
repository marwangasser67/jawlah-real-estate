import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'theme.dart';

/// A local lock screen, in addition to owner-paired server authentication.
/// First install uses the requested temporary Admin123 passcode, hashed
/// with a per-device salt in Android encrypted secure storage.
class JawlahAdminPasswordGate extends StatefulWidget {
  final Widget child;
  const JawlahAdminPasswordGate({super.key, required this.child});

  @override
  State<JawlahAdminPasswordGate> createState() =>
      _JawlahAdminPasswordGateState();
}

class _JawlahAdminPasswordGateState extends State<JawlahAdminPasswordGate>
    with WidgetsBindingObserver {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _saltKey = 'jawlah_admin_unlock_salt_v1';
  static const String _hashKey = 'jawlah_admin_unlock_digest_v1';
  static const String _failKey = 'jawlah_admin_unlock_failures_v1';
  static const String _untilKey = 'jawlah_admin_unlock_block_until_v1';

  final TextEditingController _password = TextEditingController();
  bool _ready = false;
  bool _unlocked = false;
  bool _visible = false;
  bool _checking = false;
  String? _error;
  String? _salt;
  String? _digest;
  int _failures = 0;
  DateTime? _blockedUntil;
  DateTime? _wentBackground;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  String _digestFor(String value, String salt) {
    return sha256.convert(utf8.encode(salt + ':' + value)).toString();
  }

  Future<void> _loadSettings() async {
    try {
      var salt = await _storage.read(key: _saltKey);
      var digest = await _storage.read(key: _hashKey);
      if (salt == null || digest == null) {
        final random = Random.secure();
        salt = base64Url.encode(
          List<int>.generate(24, (_) => random.nextInt(256)),
        );
        digest = _digestFor('Admin123', salt);
        await _storage.write(key: _saltKey, value: salt);
        await _storage.write(key: _hashKey, value: digest);
      }
      final failed = int.tryParse(await _storage.read(key: _failKey) ?? '');
      final blocked = int.tryParse(await _storage.read(key: _untilKey) ?? '');
      if (!mounted) return;
      setState(() {
        _salt = salt;
        _digest = digest;
        _failures = failed ?? 0;
        _blockedUntil = blocked == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(blocked);
        _ready = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _ready = true;
          _error = 'تعذر تهيئة قفل الإدارة. تحقق من تخزين الجهاز.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wentBackground = DateTime.now();
    } else if (state == AppLifecycleState.resumed &&
        _wentBackground != null) {
      // Keep auth deep-link listener mounted when returning from Chrome.
      final elapsed = DateTime.now().difference(_wentBackground!);
      _wentBackground = null;
      if (elapsed >= const Duration(seconds: 30) && _unlocked && mounted) {
        setState(() {
          _unlocked = false;
          _password.clear();
        });
      }
    }
  }

  Future<void> _unlock() async {
    if (!_ready || _checking || _unlocked) return;
    final now = DateTime.now();
    if (_blockedUntil != null && now.isBefore(_blockedUntil!)) {
      final secs = _blockedUntil!.difference(now).inSeconds + 1;
      setState(() => _error =
          'محاولات كتير غلط. حاول بعد ' +
          (secs ~/ 60 + 1).toString() + ' دقيقة.');
      return;
    }
    if (_salt == null || _digest == null) {
      setState(() => _error =
          'قفل الإدارة مش جاهز. اقفل التطبيق وافتحه تاني.');
      return;
    }
    setState(() => _checking = true);
    try {
      final attempt = _digestFor(_password.text, _salt!);
      if (attempt == _digest) {
        await _storage.delete(key: _failKey);
        await _storage.delete(key: _untilKey);
        if (!mounted) return;
        setState(() {
          _unlocked = true;
          _checking = false;
          _error = null;
          _failures = 0;
          _blockedUntil = null;
          _password.clear();
        });
        return;
      }
      _failures++;
      if (_failures >= 5) {
        _blockedUntil = DateTime.now().add(const Duration(minutes: 2));
        _failures = 0;
        await _storage.write(
          key: _untilKey,
          value: _blockedUntil!.millisecondsSinceEpoch.toString(),
        );
      }
      await _storage.write(key: _failKey, value: _failures.toString());
      if (!mounted) return;
      setState(() {
        _password.clear();
        _error = _blockedUntil != null
            ? 'خمس محاولات غلط. تم إيقاف الإدخال لمدة دقيقتين.'
            : 'كلمة المرور غير صحيحة. حاول مرة تانية.';
        _checking = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = 'تعذر فحص كلمة المرور. حاول مرة تانية.';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _password.dispose();
    super.dispose();
  }

  Widget _lockScreen(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: aBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 105,
                    width: 105,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: aPanel,
                      border: Border.all(color: aGoldDeep, width: 1.5),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Image.asset(
                      'assets/branding/jawlah_launcher.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'جولة | الإدارة',
                    style: TextStyle(
                      color: aGold,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'بوابة دخول لوحة التحكم',
                    style: TextStyle(color: aMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 30),
                  panel(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Icon(
                            Icons.lock_person_outlined,
                            color: aGold,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'الدخول إلى لوحة الإدارة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'اكتب كلمة المرور لفتح التطبيق',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: aMuted),
                        ),
                        const SizedBox(height: 23),
                        TextField(
                          controller: _password,
                          obscureText: !_visible,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.visiblePassword,
                          textInputAction: TextInputAction.done,
                          enableSuggestions: false,
                          autocorrect: false,
                          onSubmitted: (_) => _unlock(),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(
                              Icons.key_outlined,
                              color: aGoldDeep,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _visible = !_visible),
                              icon: Icon(
                                _visible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: aGold,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: aRed,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 19),
                        goldButton(
                          !_ready
                              ? 'جارٍ تجهيز قفل التطبيق...'
                              : _checking
                                  ? 'جارٍ التحقق...'
                                  : 'فتح لوحة التحكم',
                          !_ready || _checking ? null : _unlock,
                          icon: Icons.arrow_forward_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: aGoldDeep,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'قفل الجهاز إضافي، وبيانات العملاء والأرباح محمية أيضًا بحساب المدير.',
                          style: TextStyle(
                            color: aMuted,
                            fontSize: 11,
                            height: 1.7,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The owner pairing callback must remain subscribed when locked.
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: !_unlocked,
          child: widget.child,
        ),
        if (!_unlocked) _lockScreen(context),
      ],
    );
  }
}

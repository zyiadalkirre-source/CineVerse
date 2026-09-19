import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HumanChallenge {
  final String question;
  final List<String> options;
  final String answer;
  final bool visual;
  const HumanChallenge({required this.question,required this.options,required this.answer,this.visual=false});
}

class HumanVerificationService {
  static final Random _r=Random();
  static final FlutterSecureStorage _storage=FlutterSecureStorage();

  static HumanChallenge generateChallenge(){
    final a=_r.nextInt(9)+1,b=_r.nextInt(9)+1,ans=(a+b).toString();
    final values=<String>{ans};
    while(values.length<4) values.add((_r.nextInt(17)+2).toString());
    final options=values.toList()..shuffle();
    return HumanChallenge(question:'كم يساوي $a + $b ؟',options:options,answer:ans);
  }

  static HumanChallenge generateVisualChallenge(){
    const shapes=['▲','●','■','◆','★'];
    final answer=shapes[_r.nextInt(shapes.length)];
    final options=<String>{answer};
    while(options.length<4) options.add(shapes[_r.nextInt(shapes.length)]);
    final list=options.toList()..shuffle();
    return HumanChallenge(question:'اختر الشكل المطابق: $answer',options:list,answer:answer,visual:true);
  }

  static bool verify(HumanChallenge challenge,String value)=>value.trim()==challenge.answer;
  static Future<void> setAppLock(bool enabled) async => _storage.write(key:'app_lock',value:enabled?'1':'0');
  static Future<bool> isAppLockEnabled() async => (await _storage.read(key:'app_lock'))=='1';
}
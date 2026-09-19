import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreset { final String name; final int color; const ThemePreset(this.name,this.color); }

class ThemeProvider extends ChangeNotifier {
  static const presets = [
    ThemePreset('بنفسجي',0xFF7C4DFF),ThemePreset('أزرق',0xFF2196F3),ThemePreset('سماوي',0xFF00ACC1),
    ThemePreset('أخضر',0xFF43A047),ThemePreset('برتقالي',0xFFFF9800),ThemePreset('أحمر',0xFFE53935),
    ThemePreset('خمري',0xFF8E2430),ThemePreset('وردي',0xFFE91E63),ThemePreset('ذهبي',0xFFFFB300),
    ThemePreset('نيلي',0xFF3949AB),ThemePreset('ليموني',0xFF8BC34A),ThemePreset('تركوازي',0xFF00897B),
  ];
  ThemeMode _themeMode=ThemeMode.system; Locale _locale=const Locale('ar'); Color _seed=const Color(0xFF7C4DFF); bool _custom=false;
  ThemeMode get themeMode=>_themeMode; Locale get locale=>_locale; Color get seedColor=>_seed; Color get effectiveSeed=>_seed; bool get useCustom=>_custom;
  ThemeProvider(){_load();}
  Future<void> _load() async {final p=await SharedPreferences.getInstance(); final m=p.getString('themeMode')??'system'; _themeMode=ThemeMode.values.firstWhere((e)=>e.name==m,orElse:()=>ThemeMode.system); _locale=Locale(p.getString('language')??'ar'); _seed=Color(p.getInt('seedColor')??0xFF7C4DFF); _custom=p.getBool('customSeed')??false; notifyListeners();}
  Future<void> setSeed(Color c) async {_seed=c;_custom=false;notifyListeners();final p=await SharedPreferences.getInstance();await p.setInt('seedColor',c.value);await p.setBool('customSeed',false);}
  Future<void> setCustomSeed(Color c) async {_seed=c;_custom=true;notifyListeners();final p=await SharedPreferences.getInstance();await p.setInt('seedColor',c.value);await p.setBool('customSeed',true);}
  Future<void> setThemeMode(ThemeMode m) async {_themeMode=m;notifyListeners();final p=await SharedPreferences.getInstance();await p.setString('themeMode',m.name);}
  Future<void> setLocale(Locale l) async {_locale=l;notifyListeners();final p=await SharedPreferences.getInstance();await p.setString('language',l.languageCode);}
}
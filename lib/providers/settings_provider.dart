import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
class SettingsProvider extends ChangeNotifier {
  Locale _locale=const Locale('ar'); ThemeMode _themeMode=ThemeMode.system;
  Locale get locale=>_locale; ThemeMode get themeMode=>_themeMode;
  SettingsProvider(){_load();}
  Future<void> _load() async {final p=await SharedPreferences.getInstance();_locale=Locale(p.getString('language')??'ar');final m=p.getString('themeMode')??'system';_themeMode=ThemeMode.values.firstWhere((e)=>e.name==m,orElse:()=>ThemeMode.system);notifyListeners();}
  Future<void> setLocale(Locale v) async {_locale=v;notifyListeners();final p=await SharedPreferences.getInstance();await p.setString('language',v.languageCode);}
  Future<void> setThemeMode(ThemeMode v) async {_themeMode=v;notifyListeners();final p=await SharedPreferences.getInstance();await p.setString('themeMode',v.name);}
}
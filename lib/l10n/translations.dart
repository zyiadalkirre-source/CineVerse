import 'package:flutter/material.dart';

class AppTranslations {
  static const supportedLocales = [Locale('ar'), Locale('en'), Locale('fr')];
  static const Map<String,String> ar = {'app_name':'سينيفيرس','library':'مكتبتي','discover':'اكتشف','ai':'المساعد الذكي','notes':'ملاحظاتي','stats':'إحصائياتي','search':'بحث','settings':'الإعدادات','watched':'تمت المشاهدة','watching':'قيد المشاهدة','watchlist':'قائمة الانتظار','empty':'لا توجد بيانات','retry':'إعادة المحاولة','cancel':'إلغاء','save':'حفظ','clear':'مسح','rating':'تقييمي','overview':'القصة','genres':'التصنيفات','cast':'طاقم التمثيل','director':'المخرج','trailer':'الإعلان','add_note':'أضف ملاحظة','analyze':'تحليل','send':'إرسال','loading':'جارٍ التحميل...','no_api':'مفتاح API غير مضبوط'};
  static const Map<String,String> en = {'app_name':'CineVerse','library':'Library','discover':'Discover','ai':'AI Hub','notes':'Notes','stats':'Stats','search':'Search','settings':'Settings','watched':'Watched','watching':'Watching','watchlist':'Watchlist','empty':'No data','retry':'Retry','cancel':'Cancel','save':'Save','clear':'Clear','rating':'My rating','overview':'Overview','genres':'Genres','cast':'Cast','director':'Director','trailer':'Trailer','add_note':'Add note','analyze':'Analyze','send':'Send','loading':'Loading...','no_api':'API key is not configured'};
  static const Map<String,String> fr = {'app_name':'CineVerse','library':'Bibliothèque','discover':'Découvrir','ai':'Assistant IA','notes':'Notes','stats':'Statistiques','search':'Rechercher','settings':'Paramètres','watched':'Vu','watching':'En cours','watchlist':'À voir','empty':'Aucune donnée','retry':'Réessayer','cancel':'Annuler','save':'Enregistrer','clear':'Effacer','rating':'Ma note','overview':'Synopsis','genres':'Genres','cast':'Distribution','director':'Réalisateur','trailer':'Bande-annonce','add_note':'Ajouter une note','analyze':'Analyser','send':'Envoyer','loading':'Chargement...','no_api':'Clé API non configurée'};
  static Map<String,String> forLocale(Locale locale) => locale.languageCode == 'fr' ? fr : locale.languageCode == 'en' ? en : ar;
  static String text(String key, Locale locale) => forLocale(locale)[key] ?? en[key] ?? key;
}
class AppLocalizations {
  final Locale locale; const AppLocalizations(this.locale);
  static const delegate = _Delegate();
  static AppLocalizations of(BuildContext context) => Localizations.of<AppLocalizations>(context, AppLocalizations) ?? const AppLocalizations(Locale('ar'));
  String t(String key) => AppTranslations.text(key, locale);
}
class _Delegate extends LocalizationsDelegate<AppLocalizations> {
  const _Delegate();
  @override bool isSupported(Locale locale) => ['ar','en','fr'].contains(locale.languageCode);
  @override Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);
  @override bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
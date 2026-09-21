# CineVerse Roadmap

> الهدف: تثبيت التطبيق أولاً، ثم تطويره على مراحل قابلة للاختبار. لا نضيف ميزات كبيرة قبل اجتياز اختبارات البناء والتشغيل.

## 🚧 Current Priority — Stability
- إصلاح الشاشة البيضاء ومشاكل بدء التشغيل.
- تتبع أخطاء AI ومصادر البيانات الفعلية من الكود، بدون تخمين.
- إصلاح رسائل الخطأ وتجارب حالات الفشل.
- تشغيل Dart analysis والاختبارات.
- بناء Release APK والتحقق من وجوده.
- اختبار APK على جهاز فعلي قبل بدء الميزات الجديدة.

## 📦 Phase 1 — Foundation
- Splash Screen
- Onboarding (3 شرائح)
- Empty States
- Skeleton Loading
- Search History + Autocomplete
- App Icon احترافي
- اختيار اللغة داخل التطبيق

**بوابة الانتقال:** Build ناجح + Tests ناجحة + اختبار APK فعلي.

## 📦 Phase 2 — Engagement
- Achievements + XP
- Notifications ذكية
- Voice Search
- Rich Notes (flutter_quill)
- Trailer مدمج
- Calendar الإصدارات
- Mood Picker تفاعلي

**بوابة الانتقال:** Phase 1 مستقرة على APK فعلي.

## 📦 Phase 3 — Sync & Power Features
- Firebase Sync
- Friends System
- Export/Import (JSON, CSV, PDF)
- GenUI
- Image Search
- Offline Mode كامل
- Biometric Lock

**بوابة الانتقال:** Phase 2 مستقرة + لا توجد أخطاء حرجة جديدة.

## 📦 Phase 4 — Long-Term
- Watch Party
- Rewind نهاية السنة
- Movie Night Planner
- Virtual Cinema
- AI Poster Generator
- Kids Mode
- Widgets

**بوابة الانتقال:** Phase 3 مستقرة، مع مراجعة جدوى وأمان كل ميزة قبل تنفيذها.

## 🧭 Engineering Rules
1. لا نضيف ميزات كبيرة أثناء وجود خطأ حرج يمنع تشغيل التطبيق.
2. كل ميزة تُنفذ على دفعة صغيرة قابلة للاختبار.
3. لا نستخدم تخمينات عن الكود؛ نفحص المصدر الفعلي أولاً.
4. أي خدمة خارجية يجب أن تفشل بشكل آمن ولا تمنع واجهة التطبيق من الظهور.
5. أي مصدر مشاهدة يجب أن يكون قانونياً/رسمياً أو يُستبدل برابط معلوماتي قانوني.
6. بعد كل Phase: Analyze → Test → Build → تثبيت APK → اختبار فعلي.
7. لا يوجد حشو لرفع حجم التطبيق؛ أي زيادة في الحجم يجب أن تقابلها وظيفة أو أصل حقيقي مفيد.

## 📌 Status
- Current phase: **Stability / Bug Fixing**
- Next phase: **Phase 1**
- Last known startup-fix commit: `8fae7d1b8a248c4c46ba853026ec617d63fa6eb8`

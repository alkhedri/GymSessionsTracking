import 'package:flutter/widgets.dart';

enum AppLang { en, ar }

/// Plain string table rather than ARB codegen: the program content in
/// [Program] is hand-written Dart, so the translations live beside it and the
/// whole app can read them without a BuildContext.
class L {
  L._();

  static AppLang lang = AppLang.en;
  static bool get isAr => lang == AppLang.ar;
  static Locale get locale => Locale(isAr ? 'ar' : 'en');
  static TextDirection get direction =>
      isAr ? TextDirection.rtl : TextDirection.ltr;

  static String pick(String en, String ar) => isAr ? ar : en;

  static const supportedLocales = [Locale('en'), Locale('ar')];

  // ---- tabs ----------------------------------------------------------------
  static String get train => pick('Train', 'التمرين');
  static String get progress => pick('Progress', 'التقدّم');
  static String get guide => pick('Guide', 'الدليل');

  // ---- train screen --------------------------------------------------------
  static String get appName => pick('Lift Log', 'سجل التمرين');
  static String get thisWeek => pick('This week', 'هذا الأسبوع');
  static String get sessions => pick('sessions', 'حصص');
  static String get setsLogged => pick('sets logged', 'مجموعات مسجّلة');
  static String get kgTonnage => pick('kg tonnage', 'كجم حِمل كلي');
  static String get setYourGym => pick('Set your gym', 'حدّد النادي');
  static String week(int n) => pick('Week $n', 'الأسبوع $n');
  static String block(int b, int w) =>
      pick('Block $b · W$w', 'الكتلة $b · الأسبوع $w');

  static String sets(int n) => pick('$n sets', '$n مجموعة');
  static String minutes(int n) => pick('~$n min', '~$n دقيقة');
  static String doneOf(int done, int total) =>
      pick('$done/$total done', 'أُنجز $done من $total');

  // ---- session -------------------------------------------------------------
  static String get session => pick('Session', 'الحصة');
  static String get setsLabel => pick('sets', 'مجموعات');
  static String get minutesLabel => pick('minutes', 'دقيقة');
  static String get addSet => pick('+ add set', '+ إضافة مجموعة');
  static String get coachingNote => pick('Coaching note', 'ملاحظة تدريبية');
  static String get tapToRead => pick('tap to read', 'اضغط للقراءة');
  static String get halfSets => pick('half sets', 'نصف المجموعات');
  static String get enterRepsFirst =>
      pick('Enter reps first', 'أدخل عدد التكرارات أولًا');
  static String lastTime(String kg, int reps) =>
      pick('last $kg×$reps', 'آخر مرة $kg×$reps');
  static String get restGo => pick('GO', 'ابدأ');
  static String get skip => pick('Skip', 'تخطٍ');
  static String get kgTimes => pick('kg ×', 'كجم ×');
  static String get rir => pick('RIR', 'تكرارات احتياطية');
  static String get rest => pick('rest', 'راحة');
  static String restLabel(String value) => pick('$value rest', 'راحة $value');
  static String get minShort => pick('min', 'دقيقة');
  static String get secShort => pick('sec', 'ثانية');

  // ---- editing -------------------------------------------------------------
  static String get editExercises => pick('Edit exercises', 'تعديل التمارين');
  static String get editExercise => pick('Edit exercise', 'تعديل التمرين');
  static String get addExercise => pick('Add exercise', 'إضافة تمرين');
  static String get editSession => pick('Edit session', 'تعديل الحصة');
  static String get exercise => pick('Exercise', 'التمرين');
  static String get muscle => pick('Muscle', 'العضلة');
  static String get reps => pick('Reps', 'التكرارات');
  static String get setsField => pick('Sets', 'المجموعات');
  static String get restBetweenSets =>
      pick('Rest between sets', 'الراحة بين المجموعات');
  static String get save => pick('Save', 'حفظ');
  static String get cancel => pick('Cancel', 'إلغاء');
  static String get reset => pick('Reset', 'استعادة');
  static String get delete => pick('Delete', 'حذف');
  static String get remove => pick('Remove', 'إزالة');
  static String get putBack => pick('Put back', 'إرجاع');
  static String get added => pick('added', 'مُضاف');
  static String get edited => pick('edited', 'معدّل');
  static String get giveItAName => pick('Give it a name', 'أعطِه اسمًا');
  static String get required => pick('required', 'مطلوب');
  static String get removedFromDay =>
      pick('Removed from this day', 'أُزيلت من هذا اليوم');
  static String get resetToProgram =>
      pick('Reset to program', 'استعادة البرنامج الأصلي');
  static String get clearSession => pick('Clear this session', 'مسح هذه الحصة');
  static String get dragToReorder =>
      pick('Drag to reorder, tap to edit.', 'اسحب لإعادة الترتيب، واضغط للتعديل.');
  static String get longPressHint => pick(
      'Long-press "+ add set" to remove the last set of an exercise, or an exercise name to edit it.',
      'اضغط مطوّلًا على «+ إضافة مجموعة» لحذف آخر مجموعة، أو على اسم التمرين لتعديله.');
  static String get renameWarning => pick(
      'Changing this to a different machine starts a fresh history — the "last time" hint will not carry over.',
      'تغييره إلى جهاز آخر يبدأ سجلًا جديدًا — لن تنتقل إليه قراءة «آخر مرة».');
  static String get coachingNoteHint =>
      pick('setup cues, what to watch for', 'إرشادات الضبط وما ينبغي الانتباه له');

  // ---- gyms ----------------------------------------------------------------
  static String get whereTraining =>
      pick('Where are you training?', 'أين تتمرّن؟');
  static String get gymsExplainer => pick(
      'Loads are tracked separately per gym, so the "last time" hint only shows what you lifted here.',
      'تُسجَّل الأوزان لكل نادٍ على حدة، فلا تظهر قراءة «آخر مرة» إلا لما رفعته هنا.');
  static String get addGym => pick('Add gym', 'إضافة نادٍ');
  static String get renameGym => pick('Rename gym', 'إعادة تسمية النادي');
  static String get changeGym => pick('Change gym', 'تغيير النادي');
  static String get gymNameHint => pick('e.g. Downtown Gym', 'مثال: نادي المدينة');
  static String get defaultGymName => pick('My Gym', 'ناديي');
  static String get allGyms => pick('All gyms', 'كل الأندية');
  static String deleteGymQ(String name) =>
      pick('Delete $name?', 'حذف $name؟');
  static String get deleteGymBody => pick(
      'Sets you logged there are kept and still count toward your totals, but they stop feeding any gym\'s "last time" hint.',
      'تبقى المجموعات التي سجّلتها هناك ضمن إجمالياتك، لكنها تتوقف عن تغذية قراءة «آخر مرة» في أي نادٍ.');

  // ---- settings ------------------------------------------------------------
  static String get settings => pick('Settings', 'الإعدادات');
  static String get jumpToWeek => pick('Jump to a week', 'الانتقال إلى أسبوع');
  static String currentlyWeek(int n) =>
      pick('currently week $n', 'الأسبوع الحالي $n');
  static String get weekNumber => pick('week number', 'رقم الأسبوع');
  static String get go => pick('Go', 'انتقال');
  static String get exportBackup => pick('Export a backup', 'تصدير نسخة احتياطية');
  static String get exportSub =>
      pick('all sets and edits, as a file', 'كل المجموعات والتعديلات في ملف');
  static String get restoreBackup =>
      pick('Restore a backup', 'استعادة نسخة احتياطية');
  static String get restoreSub =>
      pick('replaces what is here', 'يستبدل ما هو موجود');
  static String get eraseAll => pick('Erase all data', 'محو كل البيانات');
  static String get eraseSub => pick(
      'every logged set, cannot be undone', 'كل مجموعة مسجّلة، بلا تراجع');
  static String get eraseQ =>
      pick('Erase everything?', 'محو كل شيء؟');
  static String get eraseBody => pick(
      'All logged sets, bodyweight and sleep entries will be deleted.',
      'ستُحذف كل المجموعات المسجّلة وقياسات الوزن والنوم.');
  static String get erase => pick('Erase', 'محو');
  static String get language => pick('Language', 'اللغة');
  static String get storageNote => pick(
      'Stored in SQLite on this device only — uninstalling the app deletes it. Export a backup now and then. The block repeats forever: every five weeks a new block begins.',
      'تُحفظ البيانات في قاعدة SQLite على هذا الجهاز فقط — وحذف التطبيق يمحوها. صدّر نسخة احتياطية بين حين وآخر. الكتلة تتكرر بلا نهاية: كل خمسة أسابيع تبدأ كتلة جديدة.');

  // ---- backup --------------------------------------------------------------
  static String get backupSaved => pick('Backup saved', 'حُفظت النسخة الاحتياطية');
  static String get restoreQ =>
      pick('Restore this backup?', 'استعادة هذه النسخة؟');
  static String get replace => pick('Replace', 'استبدال');
  static String restoredSets(int n) =>
      pick('Restored $n sets', 'استُعيدت $n مجموعة');
  static String backupSets(int n) =>
      pick('$n logged sets', '$n مجموعة مسجّلة');
  static String backupWeeks(int n) =>
      pick('across $n ${n == 1 ? 'week' : 'weeks'}', 'عبر $n أسبوعًا');
  static String backupEdits(int n) =>
      pick('$n edited or added exercises', '$n تمرينًا معدّلًا أو مُضافًا');
  static String backupSkipped(int n) =>
      pick('$n unreadable rows will be skipped', 'سيُتجاوز $n صفًا غير مقروء');
  static String get backupReplaceWarning => pick(
      'This replaces everything currently in the app. Export first if you want to keep what is here.',
      'سيستبدل هذا كل ما في التطبيق حاليًا. صدّر نسخة أولًا إن أردت الاحتفاظ بما لديك.');
  static String couldNotExport(String e) =>
      pick('Could not export: $e', 'تعذّر التصدير: $e');
  static String couldNotImport(String e) =>
      pick('Could not import: $e', 'تعذّرت الاستعادة: $e');

  // ---- progress ------------------------------------------------------------
  static String get tonnageByWeek =>
      pick('Tonnage by week', 'الحِمل الكلي أسبوعيًا');
  static String get bodyweightKg => pick('Bodyweight kg', 'وزن الجسم كجم');
  static String get avgSleepH => pick('Avg sleep h', 'متوسط النوم س');
  static String get howDidWeekFeel =>
      pick('How did the week feel?', 'كيف كان شعورك هذا الأسبوع؟');
  static String get oneLine => pick('one line', 'سطر واحد');
  static String weeksIn(int n) => pick('$n weeks in', 'مضى $n أسبوعًا');
  static String get weeklyHardSets =>
      pick('Weekly hard sets per muscle', 'المجموعات الفعّالة أسبوعيًا لكل عضلة');
  static String get directSetsOnly => pick(
      'Direct sets only. Indirect work sits on top of these numbers.',
      'المجموعات المباشرة فقط. العمل غير المباشر يُضاف فوق هذه الأرقام.');
  static String get volumeFooter => pick(
      '86 sets per week total. Ranges are set for compromised recovery — add sets only after the sleep improves.',
      'المجموع 86 مجموعة أسبوعيًا. النطاقات مضبوطة على تعافٍ منقوص — لا تزد المجموعات إلا بعد تحسّن النوم.');

  // ---- guide / about -------------------------------------------------------
  static String get howToRun =>
      pick('How to run the block', 'كيف تنفّذ الكتلة');
  static String get about => pick('About', 'عن التطبيق');
  static String get createdBy => pick('Created by', 'إعداد');
  static String get author => pick('Mo Khudari', 'مو خضري');
  static String get aboutBlurb => pick(
      'A gym session tracker for the 5-day machine and cable hypertrophy block. Everything stays on your device.',
      'تطبيق لتتبّع حصص النادي لبرنامج التضخيم خماسي الأيام القائم على الأجهزة والكابلات. تبقى كل بياناتك على جهازك.');
  static String get version => pick('Version', 'الإصدار');
}

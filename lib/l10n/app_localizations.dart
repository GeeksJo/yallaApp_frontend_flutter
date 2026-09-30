import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'يلا! - ٥ ثوانٍ'**
  String get appName;

  /// No description provided for @play.
  ///
  /// In ar, this message translates to:
  /// **'العب'**
  String get play;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @howToPlay.
  ///
  /// In ar, this message translates to:
  /// **'كيف تلعب'**
  String get howToPlay;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @haptics.
  ///
  /// In ar, this message translates to:
  /// **'الاهتزاز'**
  String get haptics;

  /// No description provided for @hapticsDescription.
  ///
  /// In ar, this message translates to:
  /// **'ردود فعل لمسية للنقرات وأحداث اللعب.'**
  String get hapticsDescription;

  /// No description provided for @answerTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت الإجابة'**
  String get answerTime;

  /// No description provided for @answerTimeDescription.
  ///
  /// In ar, this message translates to:
  /// **'مدة الوقت لكل لاعب للإجابة قبل انتهاء العداد.'**
  String get answerTimeDescription;

  /// No description provided for @on.
  ///
  /// In ar, this message translates to:
  /// **'مفعّل'**
  String get on;

  /// No description provided for @off.
  ///
  /// In ar, this message translates to:
  /// **'مطفأ'**
  String get off;

  /// No description provided for @oneVsOne.
  ///
  /// In ar, this message translates to:
  /// **'١ ضد ١'**
  String get oneVsOne;

  /// No description provided for @freeForAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل ضد الكل'**
  String get freeForAll;

  /// No description provided for @oneVsOneDesc.
  ///
  /// In ar, this message translates to:
  /// **'لاعبين اثنين، الهاتف ينقلب بينهم'**
  String get oneVsOneDesc;

  /// No description provided for @freeForAllDesc.
  ///
  /// In ar, this message translates to:
  /// **'٣ لاعبين أو أكثر، مرر الهاتف'**
  String get freeForAllDesc;

  /// No description provided for @playerSetup.
  ///
  /// In ar, this message translates to:
  /// **'أسماء اللاعبين'**
  String get playerSetup;

  /// No description provided for @enterPlayerName.
  ///
  /// In ar, this message translates to:
  /// **'اسم اللاعب'**
  String get enterPlayerName;

  /// No description provided for @addPlayer.
  ///
  /// In ar, this message translates to:
  /// **'أضف لاعب'**
  String get addPlayer;

  /// No description provided for @removePlayer.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get removePlayer;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @start.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ'**
  String get start;

  /// No description provided for @rounds.
  ///
  /// In ar, this message translates to:
  /// **'الجولات'**
  String get rounds;

  /// No description provided for @howManyRounds.
  ///
  /// In ar, this message translates to:
  /// **'كم جولة؟'**
  String get howManyRounds;

  /// No description provided for @chooseCategories.
  ///
  /// In ar, this message translates to:
  /// **'اختر الفئات'**
  String get chooseCategories;

  /// No description provided for @getReady.
  ///
  /// In ar, this message translates to:
  /// **'استعد!'**
  String get getReady;

  /// No description provided for @stageStartsIn.
  ///
  /// In ar, this message translates to:
  /// **'تبدأ المرحلة خلال'**
  String get stageStartsIn;

  /// No description provided for @stageStartsFootnote.
  ///
  /// In ar, this message translates to:
  /// **'الفائز من يحرز نقاط أكثر'**
  String get stageStartsFootnote;

  /// No description provided for @done.
  ///
  /// In ar, this message translates to:
  /// **'تم!'**
  String get done;

  /// No description provided for @timeUp.
  ///
  /// In ar, this message translates to:
  /// **'انتهى الوقت!'**
  String get timeUp;

  /// No description provided for @passTo.
  ///
  /// In ar, this message translates to:
  /// **'مرر الهاتف إلى'**
  String get passTo;

  /// No description provided for @tapToContinue.
  ///
  /// In ar, this message translates to:
  /// **'اضغط للمتابعة'**
  String get tapToContinue;

  /// No description provided for @scoreboard.
  ///
  /// In ar, this message translates to:
  /// **'النتائج'**
  String get scoreboard;

  /// No description provided for @playAgain.
  ///
  /// In ar, this message translates to:
  /// **'العب مرة ثانية'**
  String get playAgain;

  /// No description provided for @home.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get home;

  /// No description provided for @coins.
  ///
  /// In ar, this message translates to:
  /// **'عملات'**
  String get coins;

  /// No description provided for @rent.
  ///
  /// In ar, this message translates to:
  /// **'استئجار'**
  String get rent;

  /// No description provided for @buy.
  ///
  /// In ar, this message translates to:
  /// **'شراء'**
  String get buy;

  /// No description provided for @rentFor2Hours.
  ///
  /// In ar, this message translates to:
  /// **'استئجار لمدة ساعتين'**
  String get rentFor2Hours;

  /// No description provided for @buyForever.
  ///
  /// In ar, this message translates to:
  /// **'شراء للأبد'**
  String get buyForever;

  /// No description provided for @watchAd.
  ///
  /// In ar, this message translates to:
  /// **'شاهد إعلان'**
  String get watchAd;

  /// No description provided for @earnCoins.
  ///
  /// In ar, this message translates to:
  /// **'اكسب ٢٠ عملة'**
  String get earnCoins;

  /// No description provided for @locked.
  ///
  /// In ar, this message translates to:
  /// **'مقفل'**
  String get locked;

  /// No description provided for @unlocked.
  ///
  /// In ar, this message translates to:
  /// **'مفتوح'**
  String get unlocked;

  /// No description provided for @notEnoughCoins.
  ///
  /// In ar, this message translates to:
  /// **'لا تملك عملات كافية'**
  String get notEnoughCoins;

  /// No description provided for @selectAtLeastOne.
  ///
  /// In ar, this message translates to:
  /// **'اختر فئة واحدة على الأقل'**
  String get selectAtLeastOne;

  /// No description provided for @noPlayersSet.
  ///
  /// In ar, this message translates to:
  /// **'أضف اللاعبين من الشاشة الرئيسية قبل البدء.'**
  String get noPlayersSet;

  /// No description provided for @player.
  ///
  /// In ar, this message translates to:
  /// **'لاعب'**
  String get player;

  /// No description provided for @round.
  ///
  /// In ar, this message translates to:
  /// **'جولة'**
  String get round;

  /// No description provided for @score.
  ///
  /// In ar, this message translates to:
  /// **'النقاط'**
  String get score;

  /// No description provided for @draw.
  ///
  /// In ar, this message translates to:
  /// **'تعادل'**
  String get draw;

  /// No description provided for @drawSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'نفس النقاط - لا يوجد فائز'**
  String get drawSubtitle;

  /// No description provided for @winner.
  ///
  /// In ar, this message translates to:
  /// **'الفائز'**
  String get winner;

  /// No description provided for @howToPlayStep1.
  ///
  /// In ar, this message translates to:
  /// **'اختر وضع اللعب وأدخل أسماء اللاعبين'**
  String get howToPlayStep1;

  /// No description provided for @howToPlayStep2.
  ///
  /// In ar, this message translates to:
  /// **'اختر الفئات وعدد الجولات'**
  String get howToPlayStep2;

  /// No description provided for @howToPlayStep3.
  ///
  /// In ar, this message translates to:
  /// **'سيظهر لك سؤال - أجب قبل انتهاء العداد'**
  String get howToPlayStep3;

  /// No description provided for @howToPlayStep4.
  ///
  /// In ar, this message translates to:
  /// **'أجب بصوت عالٍ واضغط الزر الأحمر إذا أجبت'**
  String get howToPlayStep4;

  /// No description provided for @howToPlayStep5.
  ///
  /// In ar, this message translates to:
  /// **'إذا لم تستطع الإجابة، سينتهي الوقت تلقائياً'**
  String get howToPlayStep5;

  /// No description provided for @howToPlayStep6.
  ///
  /// In ar, this message translates to:
  /// **'أكثر لاعب يجمع نقاط يفوز!'**
  String get howToPlayStep6;

  /// No description provided for @paused.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get paused;

  /// No description provided for @resume.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get resume;

  /// No description provided for @editPlayers.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الأسماء'**
  String get editPlayers;

  /// No description provided for @appSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'٥ ثوانٍ'**
  String get appSubtitle;

  /// No description provided for @storeAndSupport.
  ///
  /// In ar, this message translates to:
  /// **'المتجر والدعم'**
  String get storeAndSupport;

  /// No description provided for @restorePurchases.
  ///
  /// In ar, this message translates to:
  /// **'استعادة المشتريات'**
  String get restorePurchases;

  /// No description provided for @removeAds.
  ///
  /// In ar, this message translates to:
  /// **'إزالة الإعلانات'**
  String get removeAds;

  /// No description provided for @adFreeMode.
  ///
  /// In ar, this message translates to:
  /// **'وضع بدون إعلانات مفعّل.'**
  String get adFreeMode;

  /// No description provided for @moreGames.
  ///
  /// In ar, this message translates to:
  /// **'ألعاب أخرى'**
  String get moreGames;

  /// No description provided for @moreGamesSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'جرب لعبة جديدة من قائمتنا.'**
  String get moreGamesSubtitle;

  /// No description provided for @crossPromoOpen.
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get crossPromoOpen;

  /// No description provided for @crossPromoEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ألعاب أخرى حالياً. عد لاحقاً.'**
  String get crossPromoEmpty;

  /// No description provided for @rateApp.
  ///
  /// In ar, this message translates to:
  /// **'قيّم التطبيق'**
  String get rateApp;

  /// No description provided for @supportSmall.
  ///
  /// In ar, this message translates to:
  /// **'دعم - صغير'**
  String get supportSmall;

  /// No description provided for @supportMedium.
  ///
  /// In ar, this message translates to:
  /// **'دعم - متوسط'**
  String get supportMedium;

  /// No description provided for @supportLarge.
  ///
  /// In ar, this message translates to:
  /// **'دعم - كبير'**
  String get supportLarge;

  /// No description provided for @purchaseThanks.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لدعمك!'**
  String get purchaseThanks;

  /// No description provided for @purchasesRestored.
  ///
  /// In ar, this message translates to:
  /// **'تمت استعادة المشتريات.'**
  String get purchasesRestored;

  /// No description provided for @purchaseFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر إتمام الشراء.'**
  String get purchaseFailed;

  /// No description provided for @storeUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'المتجر غير متاح على هذا الجهاز.'**
  String get storeUnavailable;

  /// No description provided for @rewardedUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'إعلان المكافأة غير متاح حالياً.'**
  String get rewardedUnavailable;

  /// No description provided for @dialogOk.
  ///
  /// In ar, this message translates to:
  /// **'موافق'**
  String get dialogOk;

  /// No description provided for @dialogCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get dialogCancel;

  /// No description provided for @dialogConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get dialogConfirm;

  /// No description provided for @errorTitle.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get errorTitle;

  /// No description provided for @confirmRemoveAdsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل اللعب بدون إعلانات؟'**
  String get confirmRemoveAdsTitle;

  /// No description provided for @confirmRemoveAdsMessage.
  ///
  /// In ar, this message translates to:
  /// **'شراء لمرة واحدة بقيمة {price} يزيل إعلان البانر وإعلانات ما بين الجولات على هذا الجهاز.\n\nيمكنك استعادة المشتريات من «استعادة المشتريات» في الإعدادات بعد إعادة التثبيت أو تغيير الجهاز.'**
  String confirmRemoveAdsMessage(String price);

  /// No description provided for @confirmRemoveAdsCta.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get confirmRemoveAdsCta;

  /// No description provided for @removeAdsBenefit1.
  ///
  /// In ar, this message translates to:
  /// **'بدون إعلان بانر'**
  String get removeAdsBenefit1;

  /// No description provided for @removeAdsBenefit2.
  ///
  /// In ar, this message translates to:
  /// **'بدون إعلانات بين الجولات'**
  String get removeAdsBenefit2;

  /// No description provided for @sectionAppInfo.
  ///
  /// In ar, this message translates to:
  /// **'التطبيق'**
  String get sectionAppInfo;

  /// No description provided for @sectionPremium.
  ///
  /// In ar, this message translates to:
  /// **'مميز'**
  String get sectionPremium;

  /// No description provided for @sectionSupport.
  ///
  /// In ar, this message translates to:
  /// **'الدعم'**
  String get sectionSupport;

  /// No description provided for @sectionContact.
  ///
  /// In ar, this message translates to:
  /// **'تواصل'**
  String get sectionContact;

  /// No description provided for @appInfoLine.
  ///
  /// In ar, this message translates to:
  /// **'يلا! - ٥ ثوانٍ - لعبة حفلات'**
  String get appInfoLine;

  /// No description provided for @removeAdsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'استمتع باللعب بدون إعلانات بانر أو بين الجولات.'**
  String get removeAdsSubtitle;

  /// No description provided for @restorePurchasesSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'استعد مشترياتك السابقة على هذا الجهاز.'**
  String get restorePurchasesSubtitle;

  /// No description provided for @donateTitle.
  ///
  /// In ar, this message translates to:
  /// **'تبرع'**
  String get donateTitle;

  /// No description provided for @donateSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ادعم التطوير بتبرع لمرة واحدة.'**
  String get donateSubtitle;

  /// No description provided for @donationPickTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر المبلغ'**
  String get donationPickTitle;

  /// No description provided for @purchaseSuccessRemoveAdsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم الشراء بنجاح'**
  String get purchaseSuccessRemoveAdsTitle;

  /// No description provided for @purchaseSuccessRemoveAdsMessage.
  ///
  /// In ar, this message translates to:
  /// **'شكراً! تمت إزالة الإعلانات على هذا الجهاز.'**
  String get purchaseSuccessRemoveAdsMessage;

  /// No description provided for @donationSuccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لدعمك!'**
  String get donationSuccessTitle;

  /// No description provided for @donationSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'تبرعك يساعدنا على تطوير يلا! - ٥ ثوانٍ. إجمالي التبرعات: {total}'**
  String donationSuccessBody(String total);

  /// No description provided for @shareApp.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة التطبيق'**
  String get shareApp;

  /// No description provided for @shareAppMessage.
  ///
  /// In ar, this message translates to:
  /// **'العب يلا! - ٥ ثوانٍ معي!'**
  String get shareAppMessage;

  /// No description provided for @websiteTitle.
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get websiteTitle;

  /// No description provided for @websiteSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'افتح الموقع الرسمي'**
  String get websiteSubtitle;

  /// No description provided for @contactEmailTitle.
  ///
  /// In ar, this message translates to:
  /// **'البريد للدعم'**
  String get contactEmailTitle;

  /// No description provided for @contactEmailSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أرسل ملاحظاتك أو أسئلتك'**
  String get contactEmailSubtitle;

  /// No description provided for @activatedLabel.
  ///
  /// In ar, this message translates to:
  /// **'مفعّل'**
  String get activatedLabel;

  /// No description provided for @restoreInProgress.
  ///
  /// In ar, this message translates to:
  /// **'جاري استعادة المشتريات…'**
  String get restoreInProgress;

  /// No description provided for @purchaseCanceled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الشراء.'**
  String get purchaseCanceled;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحميل…'**
  String get loading;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

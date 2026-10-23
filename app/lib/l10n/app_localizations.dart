import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('si')
  ];

  /// Speech component screen title
  ///
  /// In en, this message translates to:
  /// **'Say it!'**
  String get speechTitle;

  /// No description provided for @speechChooseWord.
  ///
  /// In en, this message translates to:
  /// **'Pick a word to say'**
  String get speechChooseWord;

  /// No description provided for @speechTapToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap the mic and say the word'**
  String get speechTapToRecord;

  /// No description provided for @speechRecording.
  ///
  /// In en, this message translates to:
  /// **'Listening… tap again when you\'re done'**
  String get speechRecording;

  /// No description provided for @speechChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get speechChecking;

  /// No description provided for @speechGreatJob.
  ///
  /// In en, this message translates to:
  /// **'Great job!'**
  String get speechGreatJob;

  /// No description provided for @speechAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'You said it really well.'**
  String get speechAcceptedBody;

  /// No description provided for @speechNiceTry.
  ///
  /// In en, this message translates to:
  /// **'Nice try!'**
  String get speechNiceTry;

  /// No description provided for @speechPractiseBody.
  ///
  /// In en, this message translates to:
  /// **'Let\'s practise this word together.'**
  String get speechPractiseBody;

  /// No description provided for @speechTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get speechTryAgain;

  /// No description provided for @speechNextWord.
  ///
  /// In en, this message translates to:
  /// **'Next word'**
  String get speechNextWord;

  /// No description provided for @speechMicNeeded.
  ///
  /// In en, this message translates to:
  /// **'We need the microphone to hear you. Please allow it.'**
  String get speechMicNeeded;

  /// No description provided for @speechOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get speechOpenSettings;

  /// No description provided for @speechCouldNotHear.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t hear that clearly. Let\'s try again!'**
  String get speechCouldNotHear;

  /// No description provided for @speechOfflineLater.
  ///
  /// In en, this message translates to:
  /// **'We\'ll check this when you\'re online.'**
  String get speechOfflineLater;

  /// No description provided for @speechSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Let\'s try again in a moment.'**
  String get speechSomethingWrong;

  /// No description provided for @speechListen.
  ///
  /// In en, this message translates to:
  /// **'Listen carefully'**
  String get speechListen;

  /// No description provided for @speechPlayAgain.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get speechPlayAgain;

  /// No description provided for @speechNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get speechNext;

  /// No description provided for @speechSaySound.
  ///
  /// In en, this message translates to:
  /// **'Now you say it!'**
  String get speechSaySound;

  /// No description provided for @speechBlend.
  ///
  /// In en, this message translates to:
  /// **'Now say them together'**
  String get speechBlend;

  /// No description provided for @speechWholeWordAgain.
  ///
  /// In en, this message translates to:
  /// **'Now say the whole word'**
  String get speechWholeWordAgain;

  /// No description provided for @speechStepWellDone.
  ///
  /// In en, this message translates to:
  /// **'Well done!'**
  String get speechStepWellDone;

  /// No description provided for @speechStepOnceMore.
  ///
  /// In en, this message translates to:
  /// **'Let\'s try that once more.'**
  String get speechStepOnceMore;

  /// No description provided for @speechGoodPractice.
  ///
  /// In en, this message translates to:
  /// **'Good practice! Let\'s keep going.'**
  String get speechGoodPractice;

  /// No description provided for @speechFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Great effort!'**
  String get speechFallbackTitle;

  /// No description provided for @speechFallbackBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll practise {units} again later.'**
  String speechFallbackBody(String units);

  /// No description provided for @speechCardUnlocked.
  ///
  /// In en, this message translates to:
  /// **'You unlocked a new card!'**
  String get speechCardUnlocked;

  /// No description provided for @speechLoading.
  ///
  /// In en, this message translates to:
  /// **'Getting ready…'**
  String get speechLoading;

  /// No description provided for @speechChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Which language do you want to practise?'**
  String get speechChooseLanguage;

  /// No description provided for @speechChangeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get speechChangeLanguage;

  /// No description provided for @speechLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String speechLevel(int level);

  /// No description provided for @speechHearAgain.
  ///
  /// In en, this message translates to:
  /// **'Hear again'**
  String get speechHearAgain;

  /// No description provided for @speechVoiceOff.
  ///
  /// In en, this message translates to:
  /// **'Turn the parrot\'s voice off'**
  String get speechVoiceOff;

  /// No description provided for @speechVoiceOn.
  ///
  /// In en, this message translates to:
  /// **'Turn the parrot\'s voice on'**
  String get speechVoiceOn;

  /// No description provided for @speechHearWord.
  ///
  /// In en, this message translates to:
  /// **'Hear it'**
  String get speechHearWord;

  /// No description provided for @speechHearSound.
  ///
  /// In en, this message translates to:
  /// **'Hear'**
  String get speechHearSound;

  /// No description provided for @parentDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent dashboard'**
  String get parentDashboardTitle;

  /// No description provided for @parentDashboardMenu.
  ///
  /// In en, this message translates to:
  /// **'Parent dashboard'**
  String get parentDashboardMenu;

  /// No description provided for @parentGateTitle.
  ///
  /// In en, this message translates to:
  /// **'For grown-ups'**
  String get parentGateTitle;

  /// No description provided for @parentGateQuestion.
  ///
  /// In en, this message translates to:
  /// **'What is {a} × {b}?'**
  String parentGateQuestion(int a, int b);

  /// No description provided for @parentGateWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Here is another one.'**
  String get parentGateWrong;

  /// No description provided for @parentGateOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get parentGateOpen;

  /// No description provided for @parentGateAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get parentGateAnswer;

  /// No description provided for @parentComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This section is coming soon.'**
  String get parentComingSoon;

  /// No description provided for @parentTabMath.
  ///
  /// In en, this message translates to:
  /// **'Math & Memory'**
  String get parentTabMath;

  /// No description provided for @parentTabSpelling.
  ///
  /// In en, this message translates to:
  /// **'Spelling & Phonics'**
  String get parentTabSpelling;

  /// No description provided for @parentTabHandwriting.
  ///
  /// In en, this message translates to:
  /// **'Handwriting'**
  String get parentTabHandwriting;

  /// No description provided for @parentTabSpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech & Pronunciation'**
  String get parentTabSpeech;

  /// No description provided for @speechParentBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get speechParentBoth;

  /// No description provided for @speechParentMastered.
  ///
  /// In en, this message translates to:
  /// **'Words mastered'**
  String get speechParentMastered;

  /// No description provided for @speechParentPractising.
  ///
  /// In en, this message translates to:
  /// **'Still practising'**
  String get speechParentPractising;

  /// No description provided for @speechParentNoneYet.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get speechParentNoneYet;

  /// No description provided for @speechParentSounds.
  ///
  /// In en, this message translates to:
  /// **'Sounds to practise'**
  String get speechParentSounds;

  /// No description provided for @speechParentNoSounds.
  ///
  /// In en, this message translates to:
  /// **'Nothing to practise right now. Great work!'**
  String get speechParentNoSounds;

  /// No description provided for @speechParentInWord.
  ///
  /// In en, this message translates to:
  /// **'in “{word}”'**
  String speechParentInWord(String word);

  /// No description provided for @speechParentTimes.
  ///
  /// In en, this message translates to:
  /// **'{count} times'**
  String speechParentTimes(int count);

  /// No description provided for @speechParentRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get speechParentRecent;

  /// No description provided for @speechParentDailyHint.
  ///
  /// In en, this message translates to:
  /// **'Words practised each day (last 2 weeks)'**
  String get speechParentDailyHint;

  /// No description provided for @speechParentDailySummary.
  ///
  /// In en, this message translates to:
  /// **'{count} words practised in the last 2 weeks'**
  String speechParentDailySummary(int count);

  /// No description provided for @speechParentImprovement.
  ///
  /// In en, this message translates to:
  /// **'Improvement over time'**
  String get speechParentImprovement;

  /// No description provided for @speechParentFirstTry.
  ///
  /// In en, this message translates to:
  /// **'Said right on the first try (each week)'**
  String get speechParentFirstTry;

  /// No description provided for @speechParentTriesLegend.
  ///
  /// In en, this message translates to:
  /// **'Dots: average tries per mastered word'**
  String get speechParentTriesLegend;

  /// No description provided for @speechParentTrend.
  ///
  /// In en, this message translates to:
  /// **'First-try success went from {from}% to {to}% over {weeks} weeks.'**
  String speechParentTrend(int from, int to, int weeks);

  /// No description provided for @speechParentNoTrend.
  ///
  /// In en, this message translates to:
  /// **'Practise in two different weeks to see a trend.'**
  String get speechParentNoTrend;

  /// No description provided for @speechParentThisWeek.
  ///
  /// In en, this message translates to:
  /// **'{count} words this week'**
  String speechParentThisWeek(int count);

  /// No description provided for @speechParentStreak.
  ///
  /// In en, this message translates to:
  /// **'{count}-day streak'**
  String speechParentStreak(int count);

  /// No description provided for @speechParentMasteredCount.
  ///
  /// In en, this message translates to:
  /// **'{count} mastered'**
  String speechParentMasteredCount(int count);

  /// No description provided for @speechParentTips.
  ///
  /// In en, this message translates to:
  /// **'Tips for grown-ups'**
  String get speechParentTips;

  /// No description provided for @speechParentTip1.
  ///
  /// In en, this message translates to:
  /// **'Practise little and often: 5 minutes a day works better than one long session.'**
  String get speechParentTip1;

  /// No description provided for @speechParentTip2.
  ///
  /// In en, this message translates to:
  /// **'Praise the effort, not only the right answers.'**
  String get speechParentTip2;

  /// No description provided for @speechParentTip3.
  ///
  /// In en, this message translates to:
  /// **'Say the word together slowly, then at normal speed.'**
  String get speechParentTip3;

  /// No description provided for @speechParentTip4.
  ///
  /// In en, this message translates to:
  /// **'Point to the picture and talk about the word in everyday life.'**
  String get speechParentTip4;

  /// No description provided for @speechParentSoundTip.
  ///
  /// In en, this message translates to:
  /// **'Practise the sound “{sound}” in “{word}”: say it slowly together, then say the whole word.'**
  String speechParentSoundTip(String sound, String word);

  /// No description provided for @speechParentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No speech practice on this device yet.'**
  String get speechParentEmpty;

  /// No description provided for @speechParentFootnote.
  ///
  /// In en, this message translates to:
  /// **'A practice aid, not a clinical assessment. Results are from this device only.'**
  String get speechParentFootnote;
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
      <String>['en', 'si'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'si':
      return AppLocalizationsSi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

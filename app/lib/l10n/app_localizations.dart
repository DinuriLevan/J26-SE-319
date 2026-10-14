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

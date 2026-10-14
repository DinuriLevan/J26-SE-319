// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get speechTitle => 'Say it!';

  @override
  String get speechChooseWord => 'Pick a word to say';

  @override
  String get speechTapToRecord => 'Tap the mic and say the word';

  @override
  String get speechRecording => 'Listening… tap again when you\'re done';

  @override
  String get speechChecking => 'Checking…';

  @override
  String get speechGreatJob => 'Great job!';

  @override
  String get speechAcceptedBody => 'You said it really well.';

  @override
  String get speechNiceTry => 'Nice try!';

  @override
  String get speechPractiseBody => 'Let\'s practise this word together.';

  @override
  String get speechTryAgain => 'Try again';

  @override
  String get speechNextWord => 'Next word';

  @override
  String get speechMicNeeded =>
      'We need the microphone to hear you. Please allow it.';

  @override
  String get speechOpenSettings => 'Open settings';

  @override
  String get speechCouldNotHear =>
      'We couldn\'t hear that clearly. Let\'s try again!';

  @override
  String get speechOfflineLater => 'We\'ll check this when you\'re online.';

  @override
  String get speechSomethingWrong =>
      'Something went wrong. Let\'s try again in a moment.';
}

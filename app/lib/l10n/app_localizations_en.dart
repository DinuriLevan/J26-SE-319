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

  @override
  String get speechListen => 'Listen carefully';

  @override
  String get speechPlayAgain => 'Play again';

  @override
  String get speechNext => 'Next';

  @override
  String get speechSaySound => 'Now you say it!';

  @override
  String get speechBlend => 'Now say them together';

  @override
  String get speechWholeWordAgain => 'Now say the whole word';

  @override
  String get speechStepWellDone => 'Well done!';

  @override
  String get speechStepOnceMore => 'Let\'s try that once more.';

  @override
  String get speechGoodPractice => 'Good practice! Let\'s keep going.';

  @override
  String get speechFallbackTitle => 'Great effort!';

  @override
  String speechFallbackBody(String units) {
    return 'We\'ll practise $units again later.';
  }

  @override
  String get speechCardUnlocked => 'You unlocked a new card!';

  @override
  String get speechLoading => 'Getting ready…';

  @override
  String get speechChooseLanguage => 'Which language do you want to practise?';

  @override
  String get speechChangeLanguage => 'Change language';

  @override
  String speechLevel(int level) {
    return 'Level $level';
  }

  @override
  String get speechHearAgain => 'Hear again';

  @override
  String get speechVoiceOff => 'Turn the parrot\'s voice off';

  @override
  String get speechVoiceOn => 'Turn the parrot\'s voice on';

  @override
  String get speechHearWord => 'Hear it';

  @override
  String get speechHearSound => 'Hear';

  @override
  String get parentDashboardTitle => 'Parent dashboard';

  @override
  String get parentDashboardMenu => 'Parent dashboard';

  @override
  String get parentGateTitle => 'For grown-ups';

  @override
  String parentGateQuestion(int a, int b) {
    return 'What is $a × $b?';
  }

  @override
  String get parentGateWrong => 'Not quite. Here is another one.';

  @override
  String get parentGateOpen => 'Open';

  @override
  String get parentGateAnswer => 'Answer';

  @override
  String get parentComingSoon => 'This section is coming soon.';

  @override
  String get parentTabMath => 'Math & Memory';

  @override
  String get parentTabSpelling => 'Spelling & Phonics';

  @override
  String get parentTabHandwriting => 'Handwriting';

  @override
  String get parentTabSpeech => 'Speech & Pronunciation';

  @override
  String get speechParentBoth => 'Both';

  @override
  String get speechParentMastered => 'Words mastered';

  @override
  String get speechParentPractising => 'Still practising';

  @override
  String get speechParentNoneYet => 'None yet';

  @override
  String get speechParentSounds => 'Sounds to practise';

  @override
  String get speechParentNoSounds =>
      'Nothing to practise right now. Great work!';

  @override
  String speechParentInWord(String word) {
    return 'in “$word”';
  }

  @override
  String speechParentTimes(int count) {
    return '$count times';
  }

  @override
  String get speechParentRecent => 'Recent activity';

  @override
  String get speechParentDailyHint => 'Words practised each day (last 2 weeks)';

  @override
  String speechParentDailySummary(int count) {
    return '$count words practised in the last 2 weeks';
  }

  @override
  String get speechParentImprovement => 'Improvement over time';

  @override
  String get speechParentFirstTry => 'Said right on the first try (each week)';

  @override
  String get speechParentTriesLegend => 'Dots: average tries per mastered word';

  @override
  String speechParentTrend(int from, int to, int weeks) {
    return 'First-try success went from $from% to $to% over $weeks weeks.';
  }

  @override
  String get speechParentNoTrend =>
      'Practise in two different weeks to see a trend.';

  @override
  String speechParentThisWeek(int count) {
    return '$count words this week';
  }

  @override
  String speechParentStreak(int count) {
    return '$count-day streak';
  }

  @override
  String speechParentMasteredCount(int count) {
    return '$count mastered';
  }

  @override
  String get speechParentTips => 'Tips for grown-ups';

  @override
  String get speechParentTip1 =>
      'Practise little and often: 5 minutes a day works better than one long session.';

  @override
  String get speechParentTip2 =>
      'Praise the effort, not only the right answers.';

  @override
  String get speechParentTip3 =>
      'Say the word together slowly, then at normal speed.';

  @override
  String get speechParentTip4 =>
      'Point to the picture and talk about the word in everyday life.';

  @override
  String speechParentSoundTip(String sound, String word) {
    return 'Practise the sound “$sound” in “$word”: say it slowly together, then say the whole word.';
  }

  @override
  String get speechParentEmpty => 'No speech practice on this device yet.';

  @override
  String get speechParentFootnote =>
      'A practice aid, not a clinical assessment. Results are from this device only.';
}

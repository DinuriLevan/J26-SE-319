// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Sinhala Sinhalese (`si`).
class AppLocalizationsSi extends AppLocalizations {
  AppLocalizationsSi([String locale = 'si']) : super(locale);

  @override
  String get speechTitle => 'කියමු!';

  @override
  String get speechChooseWord => 'කියන්න වචනයක් තෝරන්න';

  @override
  String get speechTapToRecord => 'මයික් එක තට්ටු කරලා වචනය කියන්න';

  @override
  String get speechRecording => 'අහගෙන ඉන්නවා… ඉවර වුණාම ආයෙත් තට්ටු කරන්න';

  @override
  String get speechChecking => 'බලනවා…';

  @override
  String get speechGreatJob => 'නියමයි!';

  @override
  String get speechAcceptedBody => 'ඔයා ඒක හරිම ලස්සනට කිව්වා.';

  @override
  String get speechNiceTry => 'හොඳ උත්සාහයක්!';

  @override
  String get speechPractiseBody => 'අපි මේ වචනය එකට පුහුණු වෙමු.';

  @override
  String get speechTryAgain => 'ආයෙත් කියමු';

  @override
  String get speechNextWord => 'ඊළඟ වචනය';

  @override
  String get speechMicNeeded =>
      'ඔයාව අහන්න මයික්‍රෆෝනය ඕනේ. කරුණාකර අවසර දෙන්න.';

  @override
  String get speechOpenSettings => 'සැකසුම් විවෘත කරන්න';

  @override
  String get speechCouldNotHear =>
      'අපිට ඒක පැහැදිලිව ඇහුණේ නෑ. ආයෙත් උත්සාහ කරමු!';

  @override
  String get speechOfflineLater => 'ඔන්ලයින් වුණාම අපි මේක බලන්නම්.';

  @override
  String get speechSomethingWrong =>
      'මොකක්හරි වැරදුණා. ටිකකින් ආයෙත් උත්සාහ කරමු.';

  @override
  String get speechListen => 'හොඳින් අහන්න';

  @override
  String get speechPlayAgain => 'ආයෙත් අහමු';

  @override
  String get speechNext => 'ඊළඟට';

  @override
  String get speechSaySound => 'දැන් ඔයා කියන්න!';

  @override
  String get speechBlend => 'දැන් එකට කියමු';

  @override
  String get speechWholeWordAgain => 'දැන් මුළු වචනයම කියමු';

  @override
  String get speechStepWellDone => 'හරිම හොඳයි!';

  @override
  String get speechStepOnceMore => 'අපි ආයෙත් වරක් උත්සාහ කරමු.';

  @override
  String get speechGoodPractice => 'හොඳ පුහුණුවක්! අපි ඉදිරියට යමු.';

  @override
  String get speechFallbackTitle => 'හොඳ උත්සාහයක්!';

  @override
  String speechFallbackBody(String units) {
    return 'අපි $units ආයෙත් පස්සේ පුහුණු වෙමු.';
  }

  @override
  String get speechCardUnlocked => 'ඔයාට අලුත් කාඩ්පතක් ලැබුණා!';

  @override
  String get speechLoading => 'සූදානම් වෙනවා…';

  @override
  String get speechChooseLanguage => 'ඔයා පුහුණු වෙන්න කැමති කුමන භාෂාවෙන්ද?';

  @override
  String get speechChangeLanguage => 'භාෂාව වෙනස් කරන්න';

  @override
  String speechLevel(int level) {
    return 'මට්ටම $level';
  }

  @override
  String get speechHearAgain => 'ආයෙත් අහන්න';

  @override
  String get speechVoiceOff => 'ගිරවාගේ කටහඬ නවත්වන්න';

  @override
  String get speechVoiceOn => 'ගිරවාගේ කටහඬ දාන්න';

  @override
  String get speechHearWord => 'අහලා බලන්න';

  @override
  String get speechHearSound => 'අහන්න';
}

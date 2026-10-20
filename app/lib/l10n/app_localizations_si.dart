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

  @override
  String get parentDashboardTitle => 'දෙමාපිය පුවරුව';

  @override
  String get parentDashboardMenu => 'දෙමාපිය පුවරුව';

  @override
  String get parentGateTitle => 'වැඩිහිටියන් සඳහා';

  @override
  String parentGateQuestion(int a, int b) {
    return '$a × $b කීයද?';
  }

  @override
  String get parentGateWrong => 'නිවැරදි නැහැ. මෙන්න තවත් එකක්.';

  @override
  String get parentGateOpen => 'විවෘත කරන්න';

  @override
  String get parentGateAnswer => 'පිළිතුර';

  @override
  String get parentComingSoon => 'මෙම කොටස ළඟදීම එකතු වේ.';

  @override
  String get parentTabMath => 'ගණිතය සහ මතකය';

  @override
  String get parentTabSpelling => 'අක්ෂර වින්‍යාසය සහ ශබ්ද';

  @override
  String get parentTabHandwriting => 'අත් අකුරු';

  @override
  String get parentTabSpeech => 'කථනය සහ උච්චාරණය';

  @override
  String get speechParentBoth => 'දෙකම';

  @override
  String get speechParentMastered => 'ප්‍රගුණ කළ වචන';

  @override
  String get speechParentPractising => 'තවමත් පුහුණු වන වචන';

  @override
  String get speechParentNoneYet => 'තවම නැත';

  @override
  String get speechParentSounds => 'පුහුණු විය යුතු ශබ්ද';

  @override
  String get speechParentNoSounds => 'දැනට පුහුණු විය යුතු දෙයක් නැත. නියමයි!';

  @override
  String speechParentInWord(String word) {
    return '“$word” වචනයේ';
  }

  @override
  String speechParentTimes(int count) {
    return 'වාර $count';
  }

  @override
  String get speechParentRecent => 'මෑත ක්‍රියාකාරකම්';

  @override
  String get speechParentDailyHint => 'දිනකට පුහුණු වූ වචන (පසුගිය සති 2)';

  @override
  String speechParentDailySummary(int count) {
    return 'පසුගිය සති 2 තුළ වචන $count ක් පුහුණු විය';
  }

  @override
  String get speechParentImprovement => 'කාලයත් සමඟ දියුණුව';

  @override
  String get speechParentFirstTry => 'පළමු වතාවේම නිවැරදිව කීවා (සතියෙන් සතිය)';

  @override
  String get speechParentTriesLegend =>
      'තිත්: ප්‍රගුණ කළ වචනයකට සාමාන්‍ය උත්සාහ ගණන';

  @override
  String speechParentTrend(int from, int to, int weeks) {
    return 'පළමු උත්සාහයේ සාර්ථකත්වය සති $weeks කදී $from% සිට $to% දක්වා වෙනස් විය.';
  }

  @override
  String get speechParentNoTrend =>
      'ප්‍රවණතාවක් බැලීමට වෙනස් සති දෙකක පුහුණු වන්න.';

  @override
  String speechParentThisWeek(int count) {
    return 'මෙම සතියේ වචන $count';
  }

  @override
  String speechParentStreak(int count) {
    return 'දින $count ක අඛණ්ඩ පුහුණුව';
  }

  @override
  String speechParentMasteredCount(int count) {
    return 'ප්‍රගුණ කළ $count';
  }

  @override
  String get speechParentTips => 'වැඩිහිටියන් සඳහා උපදෙස්';

  @override
  String get speechParentTip1 =>
      'ටිකෙන් ටික, නිතර පුහුණු වන්න: දිනකට මිනිත්තු 5ක් දිගු වාරයකට වඩා හොඳයි.';

  @override
  String get speechParentTip2 =>
      'නිවැරදි පිළිතුරු පමණක් නොව උත්සාහයද අගය කරන්න.';

  @override
  String get speechParentTip3 =>
      'වචනය එකට සෙමින් කියා, ඉන්පසු සාමාන්‍ය වේගයෙන් කියන්න.';

  @override
  String get speechParentTip4 =>
      'පින්තූරය පෙන්වා, එදිනෙදා ජීවිතයේ එම වචනය ගැන කතා කරන්න.';

  @override
  String speechParentSoundTip(String sound, String word) {
    return '“$word” වචනයේ “$sound” ශබ්දය පුහුණු වන්න: එකට සෙමින් කියා, ඉන්පසු සම්පූර්ණ වචනය කියන්න.';
  }

  @override
  String get speechParentEmpty => 'මෙම උපාංගයේ තවම කථන පුහුණුවක් නැත.';

  @override
  String get speechParentFootnote =>
      'මෙය පුහුණු ආධාරකයකි, සායනික ඇගයීමක් නොවේ. ප්‍රතිඵල මෙම උපාංගයෙන් පමණි.';
}

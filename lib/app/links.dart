import 'package:url_launcher/url_launcher.dart';

/// Donations (Ko-fi).
const kofiUrl = 'https://ko-fi.com/winzerprince';

/// Downloads (Android app and web version) on itch.io.
const itchUrl = 'https://winzer-prince.itch.io/w-calc';

/// The web version.
const webUrl = 'https://w-calc.0xwinzer.com';

/// Bug reports and ideas.
const issuesUrl = 'https://github.com/winzerprince/w-calc/issues/new/choose';

/// Source code.
const sourceUrl = 'https://github.com/winzerprince/w-calc';

/// Opens [url] in the browser; false when that is not possible.
Future<bool> openLink(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } on Object {
    return false;
  }
}

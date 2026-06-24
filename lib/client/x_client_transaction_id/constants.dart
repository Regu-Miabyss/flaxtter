const int additionalRandomNumber = 3;
const String defaultKeyword = 'obfiowerehiring';

const String onDemandFileUrlTemplate =
    'https://abs.twimg.com/responsive-web/client-web/ondemand.s.{filename}a.js';

final RegExp indicesRegex = RegExp(
  r'(\(\w{1}\[(\d{1,2})\],\s*16\))+',
  multiLine: true,
);

final RegExp onDemandFileRegex = RegExp(
  r''',(\d+):["']ondemand\.s["']''',
  multiLine: true,
);

/// Legacy inline hash format: `"ondemand.s":"HASH"`.
final RegExp onDemandFileLegacyRegex = RegExp(
  r'''["']ondemand\.s["']\s*:\s*["']([0-9a-f]+)["']''',
  multiLine: true,
);

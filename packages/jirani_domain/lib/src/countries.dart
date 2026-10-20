/// The countries JiraniChama serves. Mirrors `apps/core/countries.py` on the server.
///
/// Kenya, Uganda and Tanzania are open (owner decision 2026-10-20). The others are shown
/// as coming: Rwanda, Ethiopia and DR Congo need in-country data hosting or a regulator's
/// approval, Burundi needs a sponsor registered with its central bank, and Somalia and
/// South Sudan wait for USD and Arabic support.
class Country {
  const Country({
    required this.code,
    required this.name,
    required this.flag,
    required this.dial,
    required this.mobile,
    required this.currency,
    required this.languages,
    required this.open,
    required this.example,
  });

  final String code;
  final String name;
  final String flag;
  final String dial;

  /// The national mobile number without the leading 0, as a regular expression.
  final String mobile;
  final String currency;
  final List<String> languages;
  final bool open;
  final String example;

  RegExp get _regex => RegExp('^(?:$mobile)\$');
}

const countries = <Country>[
  Country(code: 'KE', name: 'Kenya', flag: '🇰🇪', dial: '+254', mobile: r'[17]\d{8}',
      currency: 'KES', languages: ['en', 'sw', 'so'], open: true, example: '0712 345 678'),
  Country(code: 'UG', name: 'Uganda', flag: '🇺🇬', dial: '+256', mobile: r'7\d{8}',
      currency: 'UGX', languages: ['en', 'lg', 'sw', 'nyn'], open: true,
      example: '0772 123 456'),
  Country(code: 'TZ', name: 'Tanzania', flag: '🇹🇿', dial: '+255', mobile: r'[67]\d{8}',
      currency: 'TZS', languages: ['sw', 'en'], open: true, example: '0754 123 456'),
  Country(code: 'RW', name: 'Rwanda', flag: '🇷🇼', dial: '+250', mobile: r'7\d{8}',
      currency: 'RWF', languages: ['rw', 'en', 'fr', 'sw'], open: false,
      example: '0788 123 456'),
  Country(code: 'BI', name: 'Burundi', flag: '🇧🇮', dial: '+257', mobile: r'[67]\d{7}',
      currency: 'BIF', languages: ['rn', 'fr', 'sw'], open: false, example: '79 123 456'),
  Country(code: 'CD', name: 'DR Congo', flag: '🇨🇩', dial: '+243', mobile: r'[89]\d{8}',
      currency: 'CDF', languages: ['fr', 'ln', 'sw', 'lua'], open: false,
      example: '0812 345 678'),
  Country(code: 'SS', name: 'South Sudan', flag: '🇸🇸', dial: '+211', mobile: r'9\d{8}',
      currency: 'SSP', languages: ['en', 'ar'], open: false, example: '0912 345 678'),
  Country(code: 'ET', name: 'Ethiopia', flag: '🇪🇹', dial: '+251', mobile: r'[79]\d{8}',
      currency: 'ETB', languages: ['am', 'om', 'ti', 'en'], open: false,
      example: '0911 234 567'),
  Country(code: 'SO', name: 'Somalia', flag: '🇸🇴', dial: '+252', mobile: r'[1-9]\d{7,8}',
      currency: 'USD', languages: ['so', 'ar', 'en'], open: false, example: '061 234 5678'),
];

/// Every language, in its own name. Only [translatedLanguages] can be chosen today; the
/// others are shown as coming until a reviewed translation exists.
const languageNames = <String, String>{
  'en': 'English', 'sw': 'Kiswahili', 'fr': 'Français', 'so': 'Soomaali',
  'lg': 'Luganda', 'nyn': 'Runyankore', 'rw': 'Ikinyarwanda', 'rn': 'Ikirundi',
  'ln': 'Lingála', 'lua': 'Tshiluba', 'ar': 'العربية', 'am': 'አማርኛ',
  'om': 'Afaan Oromoo', 'ti': 'ትግርኛ',
};
const translatedLanguages = {'en', 'sw'};

Country countryByCode(String? code) =>
    countries.firstWhere((c) => c.code == code, orElse: () => countries.first);

Country? countryOfE164(String e164) {
  for (final c in countries) {
    if (e164.startsWith(c.dial)) return c;
  }
  return null;
}

final RegExp _separators = RegExp(r'[\s\-().]');

/// A mobile number in international form, read the same way as the server
/// (`apps/accounts/phones.py`): a number with a country code is read in that country,
/// a local one (07…) in [country]. Returns null when it is not a mobile number there.
String? normalisePhoneIn(String raw, String country) {
  var digits = raw.replaceAll(_separators, '');
  if (digits.startsWith('00')) digits = '+${digits.substring(2)}';
  for (final c in countries) {
    final code = c.dial.substring(1);
    final plus = digits.startsWith('+$code');
    if (plus || (digits.startsWith(code) && digits.length > code.length + 6)) {
      var national = digits.substring(code.length + (plus ? 1 : 0));
      if (national.startsWith('0')) national = national.substring(1);
      return c._regex.hasMatch(national) ? '${c.dial}$national' : null;
    }
  }
  final home = countryByCode(country);
  final national = digits.startsWith('0') ? digits.substring(1) : digits;
  return home._regex.hasMatch(national) ? '${home.dial}$national' : null;
}

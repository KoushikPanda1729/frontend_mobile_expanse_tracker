class Country {
  final String name;
  final String iso; // 2-letter ISO code, also used to build the flag emoji
  final String dial; // e.g. +91
  final int minLen, maxLen; // national number length, without the dial code
  const Country(this.name, this.iso, this.dial, this.minLen, this.maxLen);

  /// Flag emoji from the ISO code (regional indicator letters).
  String get flag =>
      String.fromCharCodes(iso.codeUnits.map((c) => 0x1F1E6 + c - 0x41));
}

const india = Country('India', 'IN', '+91', 10, 10);

// ponytail: short list of common countries with typical lengths. Swap in a full
// list (or the intl_phone_number_input package) if you need every country.
const countries = <Country>[
  india,
  Country('United States', 'US', '+1', 10, 10),
  Country('United Kingdom', 'GB', '+44', 10, 10),
  Country('Canada', 'CA', '+1', 10, 10),
  Country('Australia', 'AU', '+61', 9, 9),
  Country('United Arab Emirates', 'AE', '+971', 9, 9),
  Country('Saudi Arabia', 'SA', '+966', 9, 9),
  Country('Qatar', 'QA', '+974', 8, 8),
  Country('Kuwait', 'KW', '+965', 8, 8),
  Country('Oman', 'OM', '+968', 8, 8),
  Country('Bahrain', 'BH', '+973', 8, 8),
  Country('Singapore', 'SG', '+65', 8, 8),
  Country('Malaysia', 'MY', '+60', 9, 10),
  Country('Bangladesh', 'BD', '+880', 10, 10),
  Country('Nepal', 'NP', '+977', 10, 10),
  Country('Sri Lanka', 'LK', '+94', 9, 9),
  Country('Pakistan', 'PK', '+92', 10, 10),
  Country('Bhutan', 'BT', '+975', 8, 8),
  Country('Germany', 'DE', '+49', 10, 11),
  Country('France', 'FR', '+33', 9, 9),
  Country('Italy', 'IT', '+39', 9, 10),
  Country('Spain', 'ES', '+34', 9, 9),
  Country('Netherlands', 'NL', '+31', 9, 9),
  Country('Ireland', 'IE', '+353', 9, 9),
  Country('Japan', 'JP', '+81', 10, 10),
  Country('China', 'CN', '+86', 11, 11),
  Country('South Korea', 'KR', '+82', 9, 10),
  Country('Indonesia', 'ID', '+62', 9, 12),
  Country('Thailand', 'TH', '+66', 9, 9),
  Country('Vietnam', 'VN', '+84', 9, 10),
  Country('Philippines', 'PH', '+63', 10, 10),
  Country('Russia', 'RU', '+7', 10, 10),
  Country('Turkey', 'TR', '+90', 10, 10),
  Country('Egypt', 'EG', '+20', 10, 10),
  Country('South Africa', 'ZA', '+27', 9, 9),
  Country('Nigeria', 'NG', '+234', 10, 10),
  Country('Kenya', 'KE', '+254', 9, 9),
  Country('Brazil', 'BR', '+55', 10, 11),
  Country('Mexico', 'MX', '+52', 10, 10),
  Country('New Zealand', 'NZ', '+64', 8, 10),
];

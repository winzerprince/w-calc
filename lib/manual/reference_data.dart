import 'package:wcalc_engine/wcalc_engine.dart';

/// One CONST entry: number, symbol (as on the display), name, unit, value.
typedef ConstantInfo = ({
  int number,
  String symbol,
  String name,
  String unit,
  Dec value,
});

/// One CONV entry: number, symbol (A▶B), what it converts.
typedef ConversionInfo = ({int number, String symbol, String from, String to});

const _constantNames = [
  ('proton mass', 'kg'),
  ('neutron mass', 'kg'),
  ('electron mass', 'kg'),
  ('muon mass', 'kg'),
  ('Bohr radius', 'm'),
  ('Planck constant', 'J s'),
  ('nuclear magneton', 'J T⁻¹'),
  ('Bohr magneton', 'J T⁻¹'),
  ('reduced Planck constant (h ÷ 2π)', 'J s'),
  ('fine-structure constant', 'no unit'),
  ('classical electron radius', 'm'),
  ('Compton wavelength', 'm'),
  ('proton gyromagnetic ratio', 's⁻¹ T⁻¹'),
  ('proton Compton wavelength', 'm'),
  ('neutron Compton wavelength', 'm'),
  ('Rydberg constant', 'm⁻¹'),
  ('atomic mass constant', 'kg'),
  ('proton magnetic moment', 'J T⁻¹'),
  ('electron magnetic moment', 'J T⁻¹'),
  ('neutron magnetic moment', 'J T⁻¹'),
  ('muon magnetic moment', 'J T⁻¹'),
  ('Faraday constant', 'C mol⁻¹'),
  ('elementary charge', 'C'),
  ('Avogadro constant', 'mol⁻¹'),
  ('Boltzmann constant', 'J K⁻¹'),
  ('molar volume of an ideal gas (0 °C, 1 atm)', 'm³ mol⁻¹'),
  ('molar gas constant', 'J mol⁻¹ K⁻¹'),
  ('speed of light in vacuum', 'm s⁻¹'),
  ('first radiation constant', 'W m²'),
  ('second radiation constant', 'm K'),
  ('Stefan–Boltzmann constant', 'W m⁻² K⁻⁴'),
  ('electric constant (permittivity of vacuum)', 'F m⁻¹'),
  ('magnetic constant (permeability of vacuum)', 'N A⁻²'),
  ('magnetic flux quantum', 'Wb'),
  ('standard acceleration of gravity', 'm s⁻²'),
  ('conductance quantum', 'S'),
  ('characteristic impedance of vacuum', 'Ω'),
  ('Celsius temperature (0 °C in kelvin)', 'K'),
  ('Newtonian constant of gravitation', 'm³ kg⁻¹ s⁻²'),
  ('standard atmosphere', 'Pa'),
];

const _unitNames = {
  'in': 'inches',
  'cm': 'centimetres',
  'ft': 'feet',
  'm': 'metres',
  'yd': 'yards',
  'mile': 'miles',
  'km': 'kilometres',
  'n mile': 'nautical miles',
  'acre': 'acres',
  'm²': 'square metres',
  'gal(US)': 'US gallons',
  'ℓ': 'litres',
  'gal(UK)': 'UK gallons',
  'pc': 'parsecs',
  'km/h': 'kilometres per hour',
  'm/s': 'metres per second',
  'oz': 'ounces',
  'g': 'grams',
  'lb': 'pounds',
  'kg': 'kilograms',
  'atm': 'atmospheres',
  'Pa': 'pascals',
  'mmHg': 'millimetres of mercury',
  'hp': 'horsepower',
  'kW': 'kilowatts',
  'kgf/cm²': 'kilogram-force per cm²',
  'kgf•m': 'kilogram-force metres',
  'J': 'joules',
  'lbf/in²': 'pounds-force per square inch',
  'kPa': 'kilopascals',
  '°F': 'degrees Fahrenheit',
  '°C': 'degrees Celsius',
  'cal': 'calories (15 °C)',
};

/// CONST 01–40 with values taken from the engine.
final List<ConstantInfo> constantTable = [
  for (final (i, t) in Tok.constants.indexed)
    (
      number: i + 1,
      symbol: t.text,
      name: _constantNames[i].$1,
      unit: _constantNames[i].$2,
      value: constantValues[i],
    ),
];

/// CONV 01–40 from the engine's conversion commands.
final List<ConversionInfo> conversionTable = [
  for (final (i, t) in Tok.conversions.indexed)
    () {
      final [a, b] = t.text.split('▶');
      return (
        number: i + 1,
        symbol: t.text,
        from: _unitNames[a] ?? a,
        to: _unitNames[b] ?? b,
      );
    }(),
];

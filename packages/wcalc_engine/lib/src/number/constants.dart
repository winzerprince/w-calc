/// Scientific constants (CODATA 2010, as listed in the 2nd-edition manual)
/// and metric conversions (NIST SP 811). Public-domain values.
library;

import 'dec.dart';

/// CONST 01-40 values, index 0 = CONST 01.
final List<Dec> constantValues = [
  Dec.parse('1.672621777e-27'), // mₚ
  Dec.parse('1.674927351e-27'), // mₙ
  Dec.parse('9.10938291e-31'), // mₑ
  Dec.parse('1.883531475e-28'), // mμ
  Dec.parse('5.2917721092e-11'), // a₀
  Dec.parse('6.62606957e-34'), // h
  Dec.parse('5.05078353e-27'), // μN
  Dec.parse('9.27400968e-24'), // μB
  Dec.parse('1.054571726e-34'), // ℏ
  Dec.parse('7.2973525698e-3'), // α
  Dec.parse('2.8179403267e-15'), // rₑ
  Dec.parse('2.4263102389e-12'), // λc
  Dec.parse('2.675222005e8'), // γₚ
  Dec.parse('1.32140985623e-15'), // λcₚ
  Dec.parse('1.3195909068e-15'), // λcₙ
  Dec.parse('10973731.568539'), // R∞
  Dec.parse('1.660538921e-27'), // u
  Dec.parse('1.410606743e-26'), // μₚ
  Dec.parse('-9.28476430e-24'), // μₑ
  Dec.parse('-9.6623647e-27'), // μₙ
  Dec.parse('-4.49044807e-26'), // μμ
  Dec.parse('96485.3365'), // F
  Dec.parse('1.602176565e-19'), // e
  Dec.parse('6.02214129e23'), // NA
  Dec.parse('1.3806488e-23'), // k
  Dec.parse('0.022413968'), // Vm
  Dec.parse('8.3144621'), // R
  Dec.parse('299792458'), // C₀
  Dec.parse('3.74177153e-16'), // C₁
  Dec.parse('0.014387770'), // C₂
  Dec.parse('5.670373e-8'), // σ
  Dec.parse('8.854187817e-12'), // ε₀
  Dec.parse('1.2566370614e-6'), // μ₀
  Dec.parse('2.067833758e-15'), // Φ₀
  Dec.parse('9.80665'), // g
  Dec.parse('7.7480917346e-5'), // G₀
  Dec.parse('376.730313461'), // Z₀
  Dec.parse('273.15'), // t
  Dec.parse('6.67384e-11'), // G
  Dec.parse('101325'), // atm
];

/// CONV pairs as (numerator, denominator) factors: odd number n converts
/// A▶B (× num/den), n+1 converts B▶A (× den/num). °F/°C (37, 38) are affine
/// and handled separately.
const List<(String, String)> conversionFactors = [
  ('2.54', '1'), // in ▶ cm
  ('0.3048', '1'), // ft ▶ m
  ('0.9144', '1'), // yd ▶ m
  ('1.609344', '1'), // mile ▶ km
  ('1852', '1'), // n mile ▶ m
  ('4046.8564224', '1'), // acre ▶ m²
  ('3.785411784', '1'), // gal (US) ▶ ℓ
  ('4.54609', '1'), // gal (UK) ▶ ℓ
  ('3.085678e13', '1'), // pc ▶ km
  ('1', '3.6'), // km/h ▶ m/s
  ('28.349523125', '1'), // oz ▶ g
  ('0.45359237', '1'), // lb ▶ kg
  ('101325', '1'), // atm ▶ Pa
  ('133.3224', '1'), // mmHg ▶ Pa
  ('0.7456998715822702', '1'), // hp ▶ kW
  ('98066.5', '1'), // kgf/cm² ▶ Pa
  ('9.80665', '1'), // kgf·m ▶ J
  ('6.894757293168361', '1'), // lbf/in² ▶ kPa
  ('0', '1'), // °F ▶ °C (affine, unused)
  ('1', '4.1855'), // J ▶ cal (15 °C calorie)
];

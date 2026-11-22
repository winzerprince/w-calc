import 'display_state.dart';

/// Angle unit from the setup menu (Deg default).
enum AngleUnit {
  deg(Indicator.deg),
  rad(Indicator.rad),
  gra(Indicator.gra);

  const AngleUnit(this.indicator);

  final Indicator indicator;
}

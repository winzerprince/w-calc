import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

/// Types [keys] (one character each; `{word}` for a function word) into a
/// new editor.
GxEditor typed(String keys) {
  final e = GxEditor();
  final word = RegExp(r'\{(\w+)\}');
  var i = 0;
  while (i < keys.length) {
    final m = word.matchAsPrefix(keys, i);
    if (m != null) {
      e.word(m[1]!);
      i = m.end;
      continue;
    }
    switch (keys[i]) {
      case '>' when keys.startsWith('>>', i):
        e.right();
        i += 2;
        continue;
      case '<' when keys.startsWith('<<', i):
        e.left();
        i += 2;
        continue;
      case '~':
        e.backspace();
      default:
        e.type(keys[i]);
    }
    i++;
  }
  return e;
}

GxStatement st(String text, {Set<String> functions = const {}}) =>
    gxAnalyse(GxRow.parse(text), functions: functions);

double ev(
  String text, {
  double x = 0,
  double y = 0,
  Map<String, double> vars = const {},
  bool degrees = false,
}) {
  final s = st(text);
  expect(s.f, isNotNull, reason: '$s');
  final env = GxEnv(degrees: degrees)
    ..x = x
    ..y = y;
  env.vars.addAll(vars);
  return s.f!(env);
}

void main() {
  group('editor', () {
    test('typing plain symbols', () {
      final e = typed('2x+1');
      expect(e.root.toText(), '2x+1');
      expect(e.cursor, const GxCursor([], 4));
    });

    test('letters spell function words, pi and sqrt', () {
      expect(typed('sinx').root.toText(), r'\sin x');
      expect(typed('sinh').root.toText(), r'\sinh ');
      expect(typed('arcsin').root.toText(), r'\arcsin ');
      expect(typed('2pi').root.toText(), r'2\pi ');
      expect(typed('theta').root.toText(), r'\theta ');
      final r = typed('sqrtx');
      expect(r.root.toText(), r'\sqrt{x}');
      expect(r.cursor.path, [(0, 0)]);
    });

    test('word() inserts brackets with the cursor inside', () {
      final e = typed('{cos}x');
      expect(e.root.toText(), r'\cos (x)');
      e.type(')');
      expect(e.cursor, const GxCursor([], 4));
      expect(typed('{sqrt}9').root.toText(), r'\sqrt{9}');
    });

    test('brackets close themselves at the end and before operators', () {
      expect(typed('(x+1').root.toText(), '(x+1)');
      final e = typed('x+1<<<<<<(');
      expect(e.root.toText(), '(x+1');
      expect(typed('(').root.toText(), '()');
    });

    test('/ takes the term before it as numerator', () {
      final e = typed('1+2x/3');
      expect(e.root.toText(), r'1+\frac{2x}{3}');
      expect(typed('(x+1)/2').root.toText(), r'\frac{x+1}{2}');
      expect(typed('/2').root.toText(), r'\frac{2}{}');
      expect(typed('(x+1)(x-1)/2').root.toText(), r'\frac{(x+1)(x-1)}{2}');
    });

    test('powers, subscripts and moving out with right', () {
      final e = typed('x^2>>+a_1>>');
      expect(e.root.toText(), 'x^{2}+a_{1}');
      expect(e.cursor, const GxCursor([], 5));
      e
        ..left()
        ..left();
      expect(e.cursor, const GxCursor([(4, 0)], 0));
      e
        ..left()
        ..left();
      expect(e.cursor, const GxCursor([], 3));
      e
        ..left()
        ..left();
      expect(e.cursor, const GxCursor([(1, 0)], 1));
    });

    test('left and right walk through every slot', () {
      final e = GxEditor()..box(GxKind.frac);
      e
        ..type('1')
        ..right()
        ..type('2');
      expect(e.root.toText(), r'\frac{1}{2}');
      e.right();
      expect(e.cursor, const GxCursor([], 1));
      e.left();
      expect(e.cursor, const GxCursor([(0, 1)], 1));
      e
        ..left()
        ..left();
      expect(e.cursor, const GxCursor([(0, 0)], 1));
      e
        ..left()
        ..left();
      expect(e.cursor, const GxCursor([], 0));
      e.left();
      expect(e.cursor, const GxCursor([], 0));
      e.end();
      e.right();
      expect(e.cursor, const GxCursor([], 1));
    });

    test('sum, product and integral start filled', () {
      final s = GxEditor()..box(GxKind.sum);
      expect(s.root.toText(), r'\sum{n=}{}{}');
      expect(s.cursor, const GxCursor([(0, 0)], 2));
      final p = GxEditor()..box(GxKind.prod);
      expect(p.root.toText(), r'\prod{n=}{}{}');
      final i = GxEditor()..box(GxKind.integral);
      expect(i.root.toText(), r'\integral{}{}{}{x}');
      final d = GxEditor()..box(GxKind.deriv);
      expect(d.cursor, const GxCursor([(0, 0)], 0));
      final a = GxEditor()..box(GxKind.abs);
      expect(a.root.toText(), r'\abs{}');
    });

    test('backspace deletes, pairs brackets and unwraps boxes', () {
      expect(typed('12~').root.toText(), '1');
      expect(typed('(~').root.toText(), '');
      // Into the power, then out of it keeping the contents.
      final e = typed('x^2>>');
      e.backspace();
      expect(e.cursor, const GxCursor([(1, 0)], 1));
      e
        ..backspace()
        ..backspace();
      expect(e.root.toText(), 'x');
      final f = typed('x^23<<<<~');
      expect(f.root.toText(), 'x23');
      expect(typed('1/2<<~').root.toText(), r'\frac{1}{2}');
      final h = GxEditor(GxRow.parse(r'\frac{1}{2}'))
        ..moveTo(const GxCursor([(0, 0)], 0))
        ..backspace();
      expect(h.root.toText(), r'1\div 2');
      expect(typed('~').root.toText(), '');
    });

    test('backspace at the start of later slots moves back', () {
      final e = GxEditor()..box(GxKind.root);
      e
        ..type('3')
        ..right()
        ..type('8')
        ..left();
      e.backspace();
      expect(e.cursor, const GxCursor([(0, 0)], 1));
      e.moveTo(const GxCursor([(0, 1)], 0));
      e.left();
      e.right();
      e.backspace();
      expect(e.root.toText(), r'\root{3}{8}');
      // Unwrapping keeps the radicand / body.
      final r = GxEditor(GxRow.parse(r'\root{3}{8}'))
        ..moveTo(const GxCursor([(0, 0)], 0))
        ..backspace();
      expect(r.root.toText(), '8');
      final s = GxEditor(GxRow.parse(r'\sum{n=1}{3}{n}'))
        ..moveTo(const GxCursor([(0, 0)], 0))
        ..backspace();
      expect(s.root.toText(), 'n');
      final empty = GxEditor()..box(GxKind.frac);
      empty.backspace();
      expect(empty.isEmpty, isTrue);
    });

    test('allPositions lists every caret', () {
      final e = GxEditor(GxRow.parse('x^2+1'));
      expect(e.allPositions(), hasLength(7));
      expect(e.rowAt(const [(1, 0)]).toText(), '2');
    });

    test('copy is deep', () {
      final r = GxRow.parse(r'\frac{1}{x}');
      final c = r.copy();
      (c.items.first as GxBox).slots[0].items.clear();
      expect(r.toText(), r'\frac{1}{x}');
      expect(c.items.first.toString(), 'frac{|x}');
    });
  });

  group('text', () {
    test('saved text round-trips', () {
      for (final t in [
        r'y=x^{2}+\frac{1}{x}',
        r'\sqrt{x}+\root{3}{x}\cdot \abs{x}',
        r'a_{1}\le \sin (x)\div 2',
        r'\sum{n=1}{10}{n^{2}}\ge \pi ',
        r'\integral{0}{x}{t}{t}+\deriv{x^{3}}',
        r'\prod{k=1}{4}{k}',
        r'\theta ',
      ]) {
        expect(GxRow.parse(t).toText(), t, reason: t);
      }
    });

    test('plain formulas', () {
      expect(GxRow.parse('x^2-1').toText(), 'x^{2}-1');
      expect(GxRow.parse('y = sqrt(x)/2').toText(), r'y=\frac{\sqrt{x}}{2}');
      expect(GxRow.parse('(x+1)/(x-1)').toText(), r'\frac{x+1}{x-1}');
      expect(GxRow.parse('sin(x)/x').toText(), r'\frac{\sin (x)}{x}');
      expect(GxRow.parse('2x/3').toText(), r'\frac{2x}{3}');
      expect(GxRow.parse('x²+x³').toText(), 'x^{2}+x^{3}');
      expect(GxRow.parse('x^-1').toText(), 'x^{-1}');
      expect(GxRow.parse('x^(1/3)').toText(), r'x^{\frac{1}{3}}');
      expect(GxRow.parse('2^sin(x)').toText(), r'2^{\sin (x)}');
      expect(GxRow.parse('e^{x}').toText(), 'e^{x}');
      expect(GxRow.parse('2*x−1').toText(), r'2\cdot x-1');
      expect(GxRow.parse('√x').toText(), r'\sqrt{x}');
      expect(GxRow.parse('|x-1|').toText(), r'\abs{x-1}');
      expect(GxRow.parse('|x').toText(), '|x');
      expect(GxRow.parse('abs(x)+cbrt(x)').toText(), r'\abs{x}+\root{3}{x}');
      expect(
        GxRow.parse('asin(x)+atanh(x)').toText(),
        r'\arcsin (x)+\arctanh (x)',
      );
      expect(GxRow.parse('y<=x').toText(), r'y\le x');
      expect(GxRow.parse('y>=pi').toText(), r'y\ge \pi ');
      expect(GxRow.parse('a_1').toText(), 'a_{1}');
      expect(GxRow.parse(r'\times \div').toText(), r'\cdot \div ');
      expect(GxRow.parse('x^').toText(), 'x^{}');
      expect(GxRow.parse('x^(1').toText(), 'x^{1}');
      expect(GxRow.parse('1/x^').toText(), r'\frac{1}{x}^{}');
      expect(GxRow.parse('x/').toText(), r'\frac{x}{}');
      expect(GxRow.parse('/x').toText(), r'\frac{}{x}');
      expect(GxRow.parse('x^sin').toText(), r'x^{\sin }');
      expect(GxRow.parse('a/b/c').toText(), r'\frac{\frac{a}{b}}{c}');
    });

    test('plain() reads back for labels', () {
      expect(
        GxRow.parse(
          r'\frac{1}{x}+x^{2}+a_{1}+\sqrt{x}+\root{3}{x}+\abs{x}+\sum{n=1}{2}{n}'
          r'+\prod{n=1}{2}{n}+\integral{0}{1}{t}{t}+\deriv{x}',
        ).plain(),
        '(1)/(x)+x^(2)+a_1+√(x)+root 3(x)+|x|+Σ(n=1..2) n+Π(n=1..2) n'
        '+∫(0..1) t dt+d/dx(x)',
      );
    });
  });

  group('analyse', () {
    test('shapes', () {
      expect(st('').shape, GxShape.empty);
      expect(st('x^2').shape, GxShape.function);
      expect(st('y=2x').shape, GxShape.function);
      expect(st('2x=y').shape, GxShape.function);
      expect(st('x=y^2').shape, GxShape.xFunction);
      expect(st('y^2=x').shape, GxShape.xFunction);
      expect(st('x^2+y^2=25').shape, GxShape.implicit);
      expect(st('(1,2)').shape, GxShape.point);
      expect(st('b=-3.5').shape, GxShape.slider);
      expect(st('b=-3.5').number, -3.5);
      expect(st('c=2b').shape, GxShape.define);
      expect(st('c=2b').name, 'c');
      expect(st('f(x)=x^2').shape, GxShape.userFunction);
      expect(st('2+3').shape, GxShape.value);
      expect(st('a_1=2').name, 'a_1');
    });

    test('relations', () {
      final s = st('y<x');
      expect(s.rel, GxRel.lt);
      expect(st('2x>y').rel, GxRel.lt);
      expect(st('x>y').shape, GxShape.xFunction);
      expect(st('a=x').shape, GxShape.xFunction);
      expect(st('y>=x').rel, GxRel.ge);
      expect(GxRel.values.map((r) => r.flipped), [
        GxRel.eq,
        GxRel.gt,
        GxRel.lt,
        GxRel.ge,
        GxRel.le,
      ]);
      expect(GxRel.le.inclusive, isTrue);
      expect(GxRel.lt.inclusive, isFalse);
      expect(
        [for (final r in GxRel.values) r.holds(-1)],
        [false, true, false, true, false],
      );
      expect(GxRel.eq.holds(0), isTrue);
      expect(st('x^2+y^2<4').rel, GxRel.lt);
    });

    test('errors', () {
      expect(st('y=x=2').error, contains('one ='));
      expect(st('2y').error, contains('y'));
      expect(st('=2').error, 'Incomplete');
      expect(st('a=x+y').error, contains('x or y'));
      expect(st('a=a+1').error, contains('itself'));
      expect(st('2=3').error, contains('Nothing'));
      expect(st('x+').error, 'Incomplete');
      expect(st('x)').error, contains('Unexpected'));
      expect(st('1..2').error, contains('number'));
      expect(st('(1,2,3)').error, contains('two'));
      expect(st('2(1,2)').error, contains('point'));
      expect(st('x^2^').error, 'Incomplete');
      expect(gxAnalyse(GxRow([GxBox(GxKind.pow)])).error, 'Missing base');
      expect(st('mod(x)').error, contains('2 arguments'));
      expect(st('sin(x,1)').error, contains('1 argument'));
      expect(st(r'\sum{1}{2}{n}').error, contains('n=1'));
      expect(st(r'\integral{0}{1}{x}{2}').error, contains('variable'));
      expect(st('sin').error, contains('argument'));
      expect(st(r'\foo x').error, contains('Unknown'));
      expect(st('x=').error, 'Incomplete');
    });

    test('used and free variables', () {
      final s = st('y=ax^2+b');
      expect(s.used, {'y', 'a', 'x', 'b'});
      expect(s.free({'a'}), {'b'});
      expect(st(r'\sum{n=1}{k}{n}').used, {'k'});
      expect(st('f(t)=t+c').used, {'c'});
      expect(st('2e').used, isEmpty);
      expect(st('(a,b)').used, {'a', 'b'});
      expect(st('y=2').isPlot, isTrue);
      expect(st('b=2').isPlot, isFalse);
      expect('${st('y<x')}', 'GxStatement(GxShape.function <)');
      expect('${st('b=1')}', 'GxStatement(GxShape.slider b)');
      expect('${st('x+')}', 'GxStatement(GxShape.error "Incomplete")');
    });

    test('gxDefinedFunction', () {
      expect(gxDefinedFunction(GxRow.parse('f(x)=x')), 'f');
      expect(gxDefinedFunction(GxRow.parse('g(a,b)=a+b')), 'g');
      expect(gxDefinedFunction(GxRow.parse('h_1(x)=x')), 'h_1');
      expect(gxDefinedFunction(GxRow.parse('x(t)=t')), isNull);
      expect(gxDefinedFunction(GxRow.parse('f(x)')), isNull);
      expect(gxDefinedFunction(GxRow.parse('f(x')), isNull);
      expect(gxDefinedFunction(GxRow.parse('f(2)=1')), isNull);
      expect(gxDefinedFunction(GxRow.parse('f(x)+1')), isNull);
      expect(gxDefinedFunction(GxRow.parse('f')), isNull);
      expect(gxDefinedFunction(GxRow.parse('2')), isNull);
    });
  });

  group('evaluate', () {
    test('arithmetic and precedence', () {
      expect(ev('1+2×3'), 7);
      expect(ev('-x^2', x: 3), -9);
      expect(ev('2x', x: 4), 8);
      expect(ev('x(x+1)', x: 2), 6);
      expect(ev('8÷2÷2'), 2);
      expect(ev('2·-3'), -6);
      expect(ev('+3-1'), 2);
      expect(ev('(1+2'), 3);
      expect(ev('.5+1.'), 1.5);
      expect(ev('2pi'), closeTo(2 * math.pi, 1e-12));
      expect(ev('e'), math.e);
      expect(ev('2^{3^{2}}'), 512);
      expect(ev('2^3^2'), 64);
      expect(ev('ab', vars: {'a': 2, 'b': 5}), 10);
      expect(ev('a_1+1', vars: {'a_1': 2}), 3);
      expect(ev('q').isNaN, isTrue);
    });

    test('boxes', () {
      expect(ev('1/4'), 0.25);
      expect(ev('sqrt(16)'), 4);
      expect(ev('cbrt(-8)'), -2);
      expect(ev(r'\root{4}{16}'), 2);
      expect(ev('|x|', x: -3), 3);
      expect(ev('x^(1/3)', x: -27), closeTo(-3, 1e-12));
      expect(ev('(-8)^(0.5)').isNaN, isTrue);
      expect(ev(r'\sum{n=1}{10}{n}'), 55);
      expect(ev(r'\prod{k=1}{5}{k}'), 120);
      expect(ev(r'\sum{n=1}{1000000}{n}').isNaN, isTrue);
      expect(ev(r'\integral{0}{1}{t^{2}}{t}'), closeTo(1 / 3, 1e-9));
      expect(ev(r'\integral{0}{x}{t}{t}', x: 2), closeTo(2, 1e-9));
      expect(ev(r'\integral{0}{q}{t}{t}').isNaN, isTrue);
      expect(ev(r'\deriv{x^{3}}', x: 2), closeTo(12, 1e-6));
      expect(ev('5!'), 120);
      expect(ev('0.5!'), closeTo(math.sqrt(math.pi) / 2, 1e-9));
      expect(ev('(-0.5)!'), closeTo(math.sqrt(math.pi), 1e-9));
      expect(ev('(-1)!').isNaN, isTrue);
      expect(ev('200!'), double.infinity);
      expect(ev('q!').isNaN, isTrue);
    });

    test('functions', () {
      expect(ev('sin(pi/2)'), closeTo(1, 1e-12));
      expect(ev('sin 90', degrees: true), closeTo(1, 1e-12));
      expect(ev('cos 0'), 1);
      expect(ev('tan(pi/4)'), closeTo(1, 1e-12));
      expect(ev('csc(pi/2)'), closeTo(1, 1e-12));
      expect(ev('sec 0'), 1);
      expect(ev('cot(pi/4)'), closeTo(1, 1e-12));
      expect(ev('arcsin 1', degrees: true), closeTo(90, 1e-9));
      expect(ev('arccos 1'), 0);
      expect(ev('arctan 1'), closeTo(math.pi / 4, 1e-12));
      expect(ev('arccsc 1'), closeTo(math.pi / 2, 1e-12));
      expect(ev('arcsec 1'), 0);
      expect(ev('arccot 1'), closeTo(math.pi / 4, 1e-12));
      expect(ev('sinh 0'), 0);
      expect(ev('cosh 0'), 1);
      expect(ev('tanh 0'), 0);
      expect(ev('csch 1'), closeTo(1 / 1.1752011936438014, 1e-12));
      expect(ev('sech 0'), 1);
      expect(ev('coth 1'), closeTo(1.3130352854993312, 1e-12));
      expect(ev('arcsinh 0'), 0);
      expect(ev('arccosh 1'), 0);
      expect(ev('arctanh 0'), 0);
      expect(ev('ln e'), 1);
      expect(ev('log 100'), 2);
      expect(ev(r'\log _{2}8'), closeTo(3, 1e-12));
      expect(ev('exp 0'), 1);
      expect(ev('floor(-1.5)'), -2);
      expect(ev('ceil(1.2)'), 2);
      expect(ev('round(2.5)'), 3);
      expect(ev('sign(-3)'), -1);
      expect(ev('mod(-1,3)'), 2);
      expect(ev('min(3,1,2)'), 1);
      expect(ev('max(3,1,2)'), 3);
      expect(ev(r'\sin ^{2}x+\cos ^{2}x', x: 0.7), closeTo(1, 1e-12));
      expect(ev(r'\sin ^{-1}1'), closeTo(math.pi / 2, 1e-12));
      expect(ev(r'\ln ^{-1}1'), double.infinity);
      expect(ev('sin 2x', x: 0.25), closeTo(math.sin(0.5), 1e-12));
      expect(
        ev('sin x cos x', x: 0.3),
        closeTo(math.sin(0.3) * math.cos(0.3), 1e-12),
      );
    });

    test('implicit, points and relations evaluate', () {
      final c = st('x^2+y^2=25');
      final env = GxEnv()
        ..x = 3
        ..y = 4;
      expect(c.f!(env), 0);
      final p = st('(a,2a)');
      env.vars['a'] = 3;
      expect((p.f!(env), p.g!(env)), (3, 6));
      expect(st('y=2x').f!(env), 6);
      expect(st('2x>y').f!(env), 6);
      expect(st('x=y+1').f!(env), 5);
    });

    test('user functions and variables in the environment', () {
      final def = st('f(x)=x^2+c');
      final g = st('g(a,b)=a-b');
      final env = GxEnv()..vars['c'] = 1;
      env.fns['f'] = GxUserFn(def.params, def.f!);
      env.fns['g'] = GxUserFn(g.params, g.f!);
      final use = st('y=f(x+1)+g(5,2)', functions: {'f', 'g'});
      env.x = 2;
      expect(use.f!(env), 13);
      expect(env.x, 2);
      expect(st('g(1)', functions: {'g'}).f!(env).isNaN, isTrue);
      expect(st('h(1)', functions: {'h'}).f!(env).isNaN, isTrue);
      // Runaway recursion gives NaN, not a stack overflow.
      final r = st('r(x)=r(x)', functions: {'r'});
      env.fns['r'] = GxUserFn(r.params, r.f!);
      expect(env.fns['r']!.call(env, [1]).isNaN, isTrue);
      // Binding restores what was there.
      env.bind('t', 1, () => 0);
      expect(env.vars.containsKey('t'), isFalse);
      env.bind('y', 9, () => 0);
      expect(env.y, 0);
      expect(env.get('y'), 0);
    });
  });
}

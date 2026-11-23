import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart';

import 'manual_model.dart';

// The W-Calc manual (original text). Examples are replayed on the engines
// by test/manual_examples_test.dart, so keep `verify` exact:
// two-line models → the copied result text; textbook models → the
// structured result text (fraction{7|6}, sqrt{2}, π …).

const _two = ManualAudience.twoLine;
const _tb = ManualAudience.textbook;

const manualChapters = <ManualChapter>[
  ManualChapter(
    id: 'start',
    title: 'Getting started',
    icon: Icons.play_circle_outline,
    articles: [
      ManualArticle(
        id: 'keys',
        title: 'Keys, SHIFT and ALPHA',
        summary: 'What the coloured labels mean and how to clear mistakes.',
        keywords: ['shift', 'alpha', 'ac', 'del', 'clear', 'colour'],
        blocks: [
          Para(
            'Each key has its own function plus up to two more printed above '
            'it. Press SHIFT first for the label in yellow-orange, ALPHA first '
            'for the red label (a variable or symbol). The S or A mark on the '
            'display shows that SHIFT or ALPHA is waiting.',
          ),
          Para(
            'Green labels work in BASE mode, purple ones in CMPLX mode, blue '
            'ones in the statistics modes.',
          ),
          Steps([
            ManualStep('Clear the whole calculation.', 'AC'),
            ManualStep('Delete the character next to the cursor.', 'DEL'),
            ManualStep('Move the cursor inside the calculation.', '< >'),
            ManualStep('Switch off (memories are kept).', 'SHIFT AC'),
          ]),
          Tip(
            'Tap the solar panel (top right) for full screen: the calculator '
            'fills the whole display. Tap it again to go back.',
          ),
        ],
      ),
      ManualArticle(
        id: 'arithmetic',
        title: 'Basic arithmetic and priority',
        summary: 'Type calculations as written; × and ÷ come before + and −.',
        keywords: ['add', 'multiply', 'order', 'brackets', 'parentheses'],
        blocks: [
          Para(
            'Type the calculation the way you would write it and press =. '
            'Multiplication and division are done before addition and '
            'subtraction; use brackets to change the order.',
          ),
          Example(
            title: '2 + 3 × 4',
            keys: '2 + 3 × 4 =',
            result: '14',
            verify: '14',
          ),
          Example(
            title: '(2 + 3) × 4',
            keys: '( 2 + 3 ) × 4 =',
            result: '20',
            verify: '20',
          ),
          Example(
            title: 'Negative numbers use (−), not −',
            keys: '(-) 5 + 2 =',
            result: '-3',
            verify: '-3',
          ),
          Tip(
            'A × sign may be left out before a bracket, a function, π or a '
            'variable: 2(3+4) means 2 × (3+4).',
          ),
        ],
      ),
      ManualArticle(
        id: 'math-display',
        title: 'Textbook (Math) and Linear display',
        summary: 'Fractions, roots and powers as written on paper.',
        audience: _tb,
        keywords: ['mathio', 'lineio', 'natural', 'textbook', 'setup'],
        blocks: [
          Para(
            'With Math display (the default) fractions, roots, powers, logs '
            'with a base, ∫ and Σ appear as in a textbook. Keys like □/□ and '
            '√□ open a template; type into each box and use ▶ (or ▼ / ▲ in a '
            'fraction) to move between boxes.',
          ),
          Example(
            title: '√2 + 1',
            keys: '√ 2 > + 1 =',
            result: '1 + √2',
            verify: '1+sqrt{2}',
            only: _tb,
          ),
          Para(
            'Linear display (SHIFT MODE 2) shows everything on one line, like '
            'older calculators. Results are then decimals first.',
          ),
          Steps([
            ManualStep('Math display.', 'SHIFT MODE 1 1'),
            ManualStep('Linear display.', 'SHIFT MODE 2'),
          ]),
          Tip(
            'A function with a bracket such as sin( or log( needs its closing '
            'bracket: sin(30)+15, not sin(30+15). The last brackets before = '
            'may be left out.',
          ),
        ],
      ),
    ],
  ),
  ManualChapter(
    id: 'numbers',
    title: 'Fractions, percent and angles',
    icon: Icons.percent,
    articles: [
      ManualArticle(
        id: 'fractions-two',
        title: 'Fractions',
        summary: 'Enter a b/c fractions and switch to decimals.',
        audience: _two,
        keywords: ['fraction', 'mixed', 'improper', 'ab/c', 'd/c'],
        blocks: [
          Para(
            'Press a b/c between the parts of a fraction. Results stay '
            'fractions while all inputs are fractions or whole numbers.',
          ),
          Example(
            title: '2/3 + 1/2',
            keys: '2 ab/c 3 + 1 ab/c 2 =',
            result: '1┘1┘6  (one and one sixth)',
            verify: '1┘1┘6',
          ),
          Example(
            title: 'Same result as a decimal',
            keys: '2 ab/c 3 + 1 ab/c 2 = ab/c',
            result: '1.166666667',
            verify: '1.166666667',
          ),
          Tip('SHIFT a b/c switches between mixed and improper (7┘6).'),
        ],
      ),
      ManualArticle(
        id: 'fractions-tb',
        title: 'Fractions and S⇔D',
        summary: 'Exact fraction results and switching to decimals.',
        audience: _tb,
        keywords: ['fraction', 'mixed', 'improper', 's<>d', 'decimal'],
        blocks: [
          Para(
            'Type a number and press □/□: the number becomes the numerator '
            'and the cursor moves to the denominator. Results are shown '
            'exactly when possible.',
          ),
          Example(
            title: '2/3 + 1/2',
            keys: '2 frac 3 > + 1 frac 2 =',
            result: '7/6',
            verify: 'fraction{7|6}',
          ),
          Example(
            title: 'S⇔D shows the decimal',
            keys: '2 frac 3 > + 1 frac 2 = S<>D',
            result: '1.166666667',
            verify: '1.166666667',
          ),
          Example(
            title: 'Mixed number: SHIFT S⇔D',
            keys: '2 frac 3 > + 1 frac 2 = SHIFT S<>D',
            result: '1 1/6',
            verify: 'mixed{1|1|6}',
          ),
          Example(
            title: 'Decimals are exact too',
            keys: '0.5 + 0.25 =',
            result: '3/4',
            verify: 'fraction{3|4}',
          ),
          Tip('SHIFT = gives the decimal result straight away.'),
        ],
      ),
      ManualArticle(
        id: 'exact-forms',
        title: '√ and π results',
        summary: 'Results like 2√3 + √6 or π/6 stay exact.',
        audience: _tb,
        keywords: ['root', 'surd', 'pi', 'exact', 'irrational'],
        blocks: [
          Para(
            'Square roots and multiples of π are kept exact through +, −, × '
            'and ÷ as long as the numbers stay small. S⇔D switches to the '
            'decimal and back.',
          ),
          Example(
            title: '(√2 + 2) × √3',
            keys: '( √ 2 > + 2 ) × √ 3 =',
            result: '2√3 + √6',
            verify: '2sqrt{3}+sqrt{6}',
          ),
          Example(
            title: 'π ÷ 6',
            keys: 'SHIFT EXP ÷ 6 =',
            result: 'π/6',
            verify: 'fraction{π|6}',
          ),
          Example(
            title: 'sin 45°',
            keys: 'sin 45 ) =',
            result: '√2/2',
            verify: 'fraction{sqrt{2}|2}',
          ),
        ],
      ),
      ManualArticle(
        id: 'percent',
        title: 'Percentages',
        summary: 'Percent of a value, adding and removing a percentage.',
        keywords: ['percent', '%', 'discount', 'increase'],
        blocks: [
          Para(
            'Two-line models: finish with SHIFT = (%) instead of =. '
            'Textbook models: % is SHIFT ( and divides the number before it '
            'by 100.',
          ),
          Example(
            title: '12 % of 1500',
            keys: '1500 × 12 SHIFT =',
            result: '180',
            verify: '180',
            only: _two,
          ),
          Example(
            title: '20 % of 150',
            keys: '150 × 20 SHIFT ( =',
            result: '30',
            verify: '30',
            only: _tb,
          ),
          Example(
            title: 'Increase 2500 by 15 %',
            keys: '2500 + 2500 × 15 SHIFT ( =',
            result: '2875',
            verify: '2875',
            only: _tb,
          ),
        ],
      ),
      ManualArticle(
        id: 'angles',
        title: 'Angle units and degrees-minutes-seconds',
        summary: 'Deg / Rad / Gra and °′″ input.',
        keywords: ['degree', 'radian', 'grad', 'dms', 'sexagesimal'],
        blocks: [
          Para(
            'Trigonometric functions use the angle unit shown on the display '
            '(D, R or G). Two-line models set it on the fourth MODE page; '
            'textbook models with SHIFT MODE 3 / 4 / 5.',
          ),
          Example(
            title: 'sin 30° in Deg',
            keys: 'sin 30 =',
            result: '0.5',
            verify: '0.5',
            only: _two,
          ),
          Example(
            title: 'sin 30° in Deg',
            keys: 'sin 30 ) =',
            result: '1/2',
            verify: 'fraction{1|2}',
            only: _tb,
          ),
          Example(
            title: 'sin⁻¹ 1 in Rad',
            setup: 'SHIFT MODE 4',
            keys: 'SHIFT sin 1 ) =',
            result: 'π/2',
            verify: 'fraction{π|2}',
            only: _tb,
          ),
          Para(
            'Press °′″ after degrees, minutes and seconds: 2°20′30″ is '
            '2 °′″ 20 °′″ 30 °′″.',
          ),
        ],
      ),
    ],
  ),
  ManualChapter(
    id: 'functions',
    title: 'Functions',
    icon: Icons.functions,
    articles: [
      ManualArticle(
        id: 'powers',
        title: 'Powers, roots and logarithms',
        summary: 'x², xʸ, √, ˣ√, log, ln, 10ˣ and eˣ.',
        keywords: ['power', 'square', 'root', 'log', 'ln', 'exponent'],
        blocks: [
          Example(
            title: '(1 + 1)²⁺²',
            keys: '( 1 + 1 ) ^ ( 2 + 2 ) =',
            result: '16',
            verify: '16',
            only: _two,
          ),
          Example(
            title: '(1 + 1)²⁺²',
            keys: '( 1 + 1 ) ^ 2 + 2 =',
            result: '16',
            verify: '16',
            only: _tb,
          ),
          Example(
            title: 'log₂ 16 with the log□ key',
            keys: 'logb 2 > 16 =',
            result: '4',
            verify: '4',
            only: _tb,
          ),
          Example(
            title: 'log 1000',
            keys: 'log 1000 =',
            result: '3',
            verify: '3',
            only: _two,
          ),
          Example(
            title: '⁵√32',
            keys: '5 SHIFT ^ 32 =',
            result: '2',
            verify: '2',
            only: _two,
          ),
        ],
      ),
      ManualArticle(
        id: 'combinatorics',
        title: 'Factorial, permutations, combinations, random numbers',
        summary: 'x!, nPr, nCr, Ran#.',
        keywords: ['factorial', 'npr', 'ncr', 'random', 'combination'],
        blocks: [
          Example(
            title: '5!',
            keys: '5 SHIFT x-1 =',
            result: '120',
            verify: '120',
          ),
          Example(
            title: '10P4 (arrangements of 4 from 10)',
            keys: '10 SHIFT × 4 =',
            result: '5040',
            verify: '5040',
          ),
          Example(
            title: '10C4 (choices of 4 from 10)',
            keys: '10 SHIFT ÷ 4 =',
            result: '210',
            verify: '210',
          ),
          Para(
            'SHIFT . (Ran#) gives a random number from 0.000 to 0.999. On '
            'textbook models ALPHA . (RanInt#) gives a whole number between '
            'two limits: RanInt#(1, 6) for a dice.',
          ),
        ],
      ),
      ManualArticle(
        id: 'constants',
        title: 'Scientific constants and unit conversions',
        summary: '40 constants (CONST) and 40 conversions (CONV).',
        keywords: ['constant', 'speed of light', 'convert', 'unit', 'conv'],
        blocks: [
          Para(
            'Type the two-digit number of a constant after CONST. Conversions '
            'come after the value: 5 CONV 02 turns 5 cm into inches.',
          ),
          Example(
            title: 'Speed of light (CONST 28)',
            keys: 'CONST 28 =',
            result: '299792458',
            verify: '299792458',
            only: _two,
          ),
          Example(
            title: 'Speed of light (CONST 28)',
            keys: 'SHIFT 7 28 =',
            result: '299792458',
            verify: '299792458',
            only: _tb,
          ),
          Tip(
            'Useful numbers: 01 proton mass, 23 elementary charge, '
            '24 Avogadro, 25 Boltzmann, 27 gas constant, 35 g.',
          ),
        ],
      ),
    ],
  ),
  ManualChapter(
    id: 'advanced',
    title: 'Advanced functions',
    icon: Icons.science_outlined,
    articles: [
      ManualArticle(
        id: 'hyperbolic',
        title: 'Hyperbolic functions',
        summary: 'sinh, cosh, tanh and their inverses with the hyp key.',
        keywords: ['sinh', 'cosh', 'tanh', 'hyperbolic', 'hyp'],
        blocks: [
          Para(
            'Two-line models: press hyp before sin, cos or tan (SHIFT for the '
            'inverse). Textbook models: hyp opens a menu: 1 sinh, 2 cosh, '
            '3 tanh, 4-6 the inverses. The angle unit does not matter.',
          ),
          Example(
            title: 'sinh 1',
            keys: 'hyp sin 1 =',
            result: '1.175201194',
            verify: '1.175201194',
            only: _two,
          ),
          Example(
            title: 'sinh 1',
            keys: 'hyp 1 1 ) =',
            result: '1.175201194',
            verify: '1.175201194',
            only: _tb,
          ),
        ],
      ),
      ManualArticle(
        id: 'polar',
        title: 'Polar and rectangular coordinates',
        summary: 'Pol(x, y) gives r and θ; Rec(r, θ) gives x and y.',
        keywords: ['pol', 'rec', 'polar', 'rectangular', 'coordinates'],
        blocks: [
          Para(
            'Pol is SHIFT +, Rec is SHIFT −; separate the two values with a '
            'comma. The first result is shown; both are stored: in E and F on '
            'two-line models, in X and Y on textbook models. Set the angle '
            'unit first.',
          ),
          Example(
            title: 'Pol(1, 1): r = √2 (θ = 45° in Deg)',
            keys: 'SHIFT + 1 , 1 ) =',
            result: '1.414213562',
            verify: '1.414213562',
            only: _two,
          ),
          Example(
            title: 'Pol(1, 1): r = √2 (θ = 45° in Deg)',
            keys: 'SHIFT + 1 SHIFT ) 1 ) =',
            result: '√2',
            verify: 'sqrt{2}',
            only: _tb,
          ),
        ],
      ),
      ManualArticle(
        id: 'engineering',
        title: 'Engineering notation',
        summary: 'ENG moves the decimal point in steps of three.',
        keywords: ['eng', 'engineering', 'exponent', 'notation'],
        blocks: [
          Para(
            'After a result, ENG shows it with an exponent that is a multiple '
            'of 3; SHIFT ENG (←) moves the other way.',
          ),
          Example(
            title: '1234 in engineering notation',
            keys: '1234 = ENG',
            result: '1.234 × 10³',
            verify: '1.234E03',
            only: _two,
          ),
          Example(
            title: '1234 in engineering notation',
            keys: '1234 = ENG',
            result: '1.234 × 10³',
            verify: '1.234×tenPow{3}',
            only: _tb,
          ),
        ],
      ),
      ManualArticle(
        id: 'drg',
        title: 'Converting angle units (DRG▸)',
        summary: 'Mark a value as degrees, radians or grads.',
        keywords: ['drg', 'radian', 'degree', 'grad', 'convert angle'],
        blocks: [
          Para(
            'SHIFT Ans (DRG▸) then 1 °, 2 r or 3 g marks the value before it; '
            'it is converted to the angle unit in use.',
          ),
          Example(
            title: 'π/2 radians in degrees',
            keys: '( SHIFT EXP ÷ 2 ) SHIFT Ans 2 =',
            result: '90',
            verify: '90',
          ),
        ],
      ),
      ManualArticle(
        id: 'sexagesimal',
        title: 'Degrees, minutes and seconds',
        summary: 'Enter °′″ values and convert to decimals.',
        keywords: ['dms', 'minutes', 'seconds', 'sexagesimal', 'time'],
        blocks: [
          Para(
            'Press °′″ after the degrees, the minutes and the seconds. On a '
            'result, °′″ switches between degrees-minutes-seconds and the '
            'decimal (two-line models use SHIFT °′″ to show a decimal result '
            'in °′″).',
          ),
          Example(
            title: '2°15′18″ as a decimal',
            keys: '2 °′″ 15 °′″ 18 °′″ = °′″',
            result: '2.255',
            verify: '2.255',
          ),
        ],
      ),
      ManualArticle(
        id: 'multistatement',
        title: 'Several calculations in one line',
        summary: 'Join calculations with : (ALPHA ∫dx).',
        keywords: ['multi-statement', 'colon', 'disp', 'chain'],
        blocks: [
          Para(
            'Type : with ALPHA ∫dx between calculations. = shows the first '
            'result (Disp on the display); each further = shows the next.',
          ),
          Example(
            title: '3 + 3 : 3 × 3',
            keys: '3 + 3 ALPHA ∫dx 3 × 3 =',
            result: '6, then = gives 9',
            verify: '6',
          ),
        ],
      ),
      ManualArticle(
        id: 'abs-rnd',
        title: 'Absolute value and rounding (Abs, Rnd)',
        summary: '|x| and rounding to the display format.',
        keywords: ['abs', 'absolute', 'rnd', 'round', 'rounding'],
        blocks: [
          Para(
            'Abs gives the distance from zero. Rnd (SHIFT 0) rounds a value '
            'to the digits shown by Fix, Sci or Norm, so later steps use the '
            'rounded number.',
          ),
          Example(
            title: '|2 − 7| × 2',
            keys: 'SHIFT hyp 2 - 7 > × 2 =',
            result: '10',
            verify: '10',
            only: _tb,
          ),
          Example(
            title: 'Rnd(10 ÷ 3) × 3 with Fix 3 (Linear display)',
            setup: 'SHIFT MODE 2 SHIFT MODE 6 3',
            keys: 'SHIFT 0 10 ÷ 3 ) × 3 =',
            result: '9.999',
            verify: '9.999',
            only: _tb,
          ),
        ],
      ),
      ManualArticle(
        id: 'history',
        title: 'Replay and history',
        summary: 'Edit the last calculation or step back through earlier ones.',
        keywords: ['replay', 'history', 'edit', 'previous', 'up'],
        blocks: [
          Para(
            'Right after a result, ◀ or ▶ opens the calculation for editing; '
            'change it and press = again. ▲ and ▼ step through earlier '
            'calculations and their results. History clears when the mode '
            'changes or the calculator is switched off.',
          ),
        ],
      ),
    ],
  ),
  ManualChapter(
    id: 'memory',
    title: 'Memories',
    icon: Icons.save_outlined,
    articles: [
      ManualArticle(
        id: 'variables',
        title: 'Ans, variables and M',
        summary: 'Store, recall and reuse results.',
        keywords: ['memory', 'store', 'recall', 'sto', 'rcl', 'ans', 'm+'],
        blocks: [
          Para(
            'Ans always holds the last result; pressing an operator right '
            'after a result continues from it. SHIFT RCL (STO) and a letter '
            'key store a value; RCL and the letter show it; ALPHA and the '
            'letter type its name into a calculation.',
          ),
          Example(
            title: 'Continue from Ans',
            keys: '3 × 4 = ÷ 30 =',
            result: '0.4',
            verify: '0.4',
            only: _two,
          ),
          Example(
            title: 'Continue from Ans',
            keys: '3 × 4 = ÷ 30 =',
            result: '2/5',
            verify: 'fraction{2|5}',
            only: _tb,
          ),
          Example(
            title: 'Store 8 in A, then A × 10',
            keys: '3 + 5 SHIFT RCL (-) AC ALPHA (-) × 10 =',
            result: '80',
            verify: '80',
          ),
          Para(
            'M+ adds the result to memory M, SHIFT M+ subtracts it. Memories '
            'stay when the app closes. SHIFT 9 (textbook) or SHIFT MODE '
            '(two-line) clears them.',
          ),
        ],
      ),
    ],
  ),
  ManualChapter(
    id: 'calculus',
    title: 'Calculus, CALC and SOLVE',
    icon: Icons.area_chart_outlined,
    articles: [
      ManualArticle(
        id: 'integration',
        title: 'Integration',
        summary: 'Definite integrals with ∫dx.',
        keywords: ['integral', 'integrate', 'area', '∫'],
        blocks: [
          Para(
            'Two-line models: ∫dx f(X) , a , b ). Textbook models: press ∫□, '
            'type f(X), then ▶ the lower limit, ▶ the upper limit. Type X '
            'with ALPHA ). Integration takes a moment.',
          ),
          Example(
            title: '∫₀³ x² dx',
            keys: '∫dx X x2 , 0 , 3 ) =',
            result: '9',
            verify: '9',
            only: _two,
          ),
          Example(
            title: '∫₀³ x² dx',
            keys: '∫dx X x2 > 0 > 3 =',
            result: '9',
            verify: '9',
            only: _tb,
          ),
          Tip(
            'Use Rad for integrals of trigonometric functions. Split an '
            'interval where the function changes sign for a better result.',
          ),
        ],
      ),
      ManualArticle(
        id: 'derivative',
        title: 'Derivative at a point',
        summary: 'd/dx f(X) at X = a.',
        keywords: ['derivative', 'differentiate', 'slope', 'gradient'],
        blocks: [
          Example(
            title: 'd/dx x² at x = 3',
            keys: 'd/dx X x2 , 3 ) =',
            result: '6',
            verify: '6',
            only: _two,
          ),
          Example(
            title: 'd/dx x² at x = 3',
            keys: 'SHIFT ∫dx X x2 > 3 =',
            result: '6',
            verify: '6',
            only: _tb,
          ),
        ],
      ),
      ManualArticle(
        id: 'sum',
        title: 'Sums with Σ',
        summary: 'Add f(X) for X from a to b.',
        audience: _tb,
        keywords: ['sigma', 'sum', 'series'],
        blocks: [
          Para(
            'SHIFT log□ opens Σ: type f(X), ▶ the first X, ▶ the last X. '
            'Both limits are whole numbers.',
          ),
          Example(
            title: 'Σ (X + 1) for X = 1 … 5',
            keys: 'SHIFT logb X + 1 > 1 > 5 =',
            result: '20',
            verify: '20',
          ),
        ],
      ),
      ManualArticle(
        id: 'calc',
        title: 'CALC: evaluate a formula for different values',
        summary: 'Store an expression, then enter values for its variables.',
        keywords: ['calc', 'formula', 'substitute', 'variable'],
        blocks: [
          Para(
            'Type an expression with variables and press CALC. The '
            'calculator asks for each variable; type a value and press =. '
            'Press CALC again for other values.',
          ),
          Example(
            title: 'X² + 1 for X = 3',
            keys: 'X x2 + 1 CALC 3 =',
            result: '10',
            verify: '10',
            only: _two,
          ),
          Example(
            title: '3A + B for A = 5, B = 10',
            keys: '3 ALPHA (-) + ALPHA °′″ CALC 5 = 10 =',
            result: '25',
            verify: '25',
            only: _tb,
          ),
          Tip(
            'Start with a variable and = (ALPHA CALC) to store the result: '
            'Y = X² + X + 3 puts the answer in Y.',
          ),
        ],
      ),
      ManualArticle(
        id: 'solve',
        title: 'SOLVE: find where an equation holds',
        summary: 'Newton’s method from a starting guess.',
        keywords: ['solve', 'root', 'equation', 'newton'],
        blocks: [
          Para(
            'Type the equation (ALPHA CALC types =); an expression alone '
            'means "= 0". Press SHIFT CALC, give values for the other '
            'variables, type a starting guess for X and press SHIFT CALC '
            'again. Only one solution is found; try other guesses for others.',
          ),
          Tip('If no solution appears, start closer to the expected answer.'),
        ],
      ),
    ],
  ),
  ManualChapter(
    id: 'modes',
    title: 'Modes',
    icon: Icons.apps,
    articles: [
      ManualArticle(
        id: 'complex',
        title: 'Complex numbers (CMPLX)',
        summary: 'a + bi and r∠θ arithmetic.',
        audience: _two,
        requires: {CalcMode.cmplx},
        keywords: ['complex', 'imaginary', 'i', 'polar', 'cmplx'],
        blocks: [
          Steps([ManualStep('Enter CMPLX mode.', 'MODE 2')]),
          Para(
            'ENG types i and SHIFT (−) types ∠. The real part shows first; '
            'SHIFT = (Re⇔Im) shows the imaginary part.',
          ),
          Example(
            title: '(2 + 6i) ÷ 2i: real part',
            setup: 'MODE 2',
            keys: '( 2 + 6 i ) ÷ ( 2 i ) =',
            result: '3  (Re⇔Im shows −1, so 3 − i)',
            verify: '3',
          ),
        ],
      ),
      ManualArticle(
        id: 'complex-tb',
        title: 'Complex numbers (CMPLX)',
        summary: 'a + bi and r∠θ, with exact parts.',
        audience: _tb,
        keywords: ['complex', 'imaginary', 'i', 'polar', 'cmplx', 'conjugate'],
        blocks: [
          Steps([ManualStep('Enter CMPLX mode.', 'MODE 2')]),
          Para(
            'In CMPLX mode ENG types i and SHIFT (−) types ∠. SHIFT 2 opens '
            'arg, Conjg, ▶r∠θ and ▶a+bi. Results show both parts at once.',
          ),
          Example(
            title: '(2 + 6i) ÷ 2i',
            setup: 'MODE 2',
            keys: '( 2 + 6 ENG ) ÷ ( 2 ENG ) =',
            result: '3 − i',
            verify: '3-i',
          ),
          Example(
            title: '(1 − i)⁻¹',
            setup: 'MODE 2',
            keys: '( 1 - ENG ) x-1 =',
            result: '1/2 + 1/2 i',
            verify: 'fraction{1|2}+fraction{1|2}i',
          ),
          Example(
            title: '√2 + √2 i in polar form',
            setup: 'MODE 2',
            keys: '√ 2 > + √ 2 > ENG SHIFT 2 3 =',
            result: '2∠45',
            verify: '2∠45',
          ),
        ],
      ),
      ManualArticle(
        id: 'sd',
        title: 'Single-variable statistics (SD)',
        summary: 'Mean, standard deviation and sums of a data list.',
        audience: _two,
        requires: {CalcMode.sd},
        keywords: ['statistics', 'mean', 'average', 'standard deviation'],
        blocks: [
          Steps([
            ManualStep('Enter SD mode.', 'MODE MODE 1'),
            ManualStep('Clear old data.', 'SHIFT MODE 1 ='),
            ManualStep('Enter each value with DT (M+).', '10 DT 20 DT 30 DT'),
            ManualStep('Mean x̄: S-VAR 1.', 'S-VAR 1 ='),
          ]),
          Example(
            title: 'Mean of 10, 20, 30',
            setup: 'MODE MODE 1',
            keys: '10 DT 20 DT 30 DT S-VAR 1 =',
            result: '20',
            verify: '20',
          ),
        ],
      ),
      ManualArticle(
        id: 'stat-tb',
        title: 'Statistics and regression (STAT)',
        summary: 'Stat Editor, mean, standard deviation and regression.',
        audience: _tb,
        keywords: [
          'statistics',
          'mean',
          'average',
          'standard deviation',
          'regression',
          'correlation',
          'frequency',
        ],
        blocks: [
          Steps([
            ManualStep(
              'Enter STAT mode and choose a type (1 for one variable).',
              'MODE 3 1',
            ),
            ManualStep(
              'Type each value and press = (the editor moves down).',
              '10 = 20 = 30 =',
            ),
            ManualStep('Leave the editor for calculations.', 'AC'),
            ManualStep(
              'SHIFT 1 opens the STAT menu: Sum, Var, Reg or Distr, MinMax.',
            ),
          ]),
          Example(
            title: 'Mean of 10, 20, 30',
            setup: 'MODE 3 1 10 = 20 = 30 = AC',
            keys: 'SHIFT 1 4 2 =',
            result: '20',
            verify: '20',
          ),
          Para(
            'Paired data (types 2-8): type the X column, go back up with ▲, '
            'move to Y with ▶ and type the Y values. Reg gives A, B, r and the '
            'estimates x̂ and ŷ: 160 x̂… or 160 ŷ.',
          ),
          Example(
            title: 'Linear regression: y at x = 4 for (1,3), (2,5), (3,7)',
            setup: 'MODE 3 2 1 = 2 = 3 = up up up > 3 = 5 = 7 = AC',
            keys: '4 SHIFT 1 5 5 =',
            result: '9',
            verify: '9',
          ),
          Tip(
            'SHIFT MODE ▼ 4 turns on the FREQ column for repeated values. '
            'Changing it, switching between one-variable and paired types, '
            'or leaving STAT deletes the data. DEL deletes the row under the '
            'cursor.',
          ),
        ],
      ),
      ManualArticle(
        id: 'base',
        title: 'Number systems (BASE)',
        summary: 'Decimal, hexadecimal, binary and octal.',
        audience: _two,
        requires: {CalcMode.base},
        keywords: ['binary', 'hex', 'octal', 'base', 'logic'],
        blocks: [
          Steps([
            ManualStep('Enter BASE mode.', 'MODE MODE 3'),
            ManualStep('Choose binary with BIN (log key).', 'BIN'),
          ]),
          Example(
            title: '11₂ + 1₂',
            setup: 'MODE MODE 3',
            keys: 'BIN 11 + 1 =',
            result: '100 (binary)',
            verify: '100',
          ),
        ],
      ),
      ManualArticle(
        id: 'eqn',
        title: 'Equations (EQN)',
        summary: 'Simultaneous, quadratic and cubic equations.',
        audience: _two,
        requires: {CalcMode.eqn},
        keywords: ['equation', 'quadratic', 'cubic', 'simultaneous', 'roots'],
        blocks: [
          Para(
            'Choose EQN, then the number of unknowns (2 or 3), or ▶ for a '
            'degree (2 quadratic, 3 cubic). Enter each coefficient and press '
            '=. ▼ shows the next solution.',
          ),
          Example(
            title: 'x² − 3x + 2 = 0',
            keys: 'MODE MODE MODE 1 > 2 1 = (-) 3 = 2 =',
            result: 'x1 = 2, x2 = 1',
            verify: '2',
          ),
        ],
      ),
      ManualArticle(
        id: 'eqn-tb',
        title: 'Equations (EQN)',
        summary:
            'Simultaneous, quadratic and cubic equations with exact roots.',
        audience: _tb,
        keywords: ['equation', 'quadratic', 'cubic', 'simultaneous', 'roots'],
        blocks: [
          Steps([
            ManualStep(
              'Enter EQN and pick a type (3 = quadratic).',
              'MODE 5 3',
            ),
            ManualStep(
              'Type each coefficient and press = (fractions and √ allowed).',
            ),
            ManualStep(
              'Press = on its own to solve; = or ▼ shows the next root.',
            ),
            ManualStep('AC resets the coefficients to 0.'),
          ]),
          Example(
            title: 'x² + x + 3/4 = 0',
            keys: 'MODE 5 3 1 = 1 = 3 frac 4 = =',
            result: 'X1 = −1/2 + (√2/2) i',
            note: '▼ shows X2 = −1/2 − (√2/2) i.',
          ),
          Example(
            title: 'x + 2y = 3, 2x + 3y = 4',
            keys: 'MODE 5 1 1 = 2 = 3 = 2 = 3 = 4 = =',
            result: 'X = −1, then ▼ Y = 2',
          ),
        ],
      ),
      ManualArticle(
        id: 'base-tb',
        title: 'Number systems (BASE-N)',
        summary: 'Decimal, hexadecimal, binary and octal with logic.',
        audience: _tb,
        keywords: ['binary', 'hex', 'octal', 'base', 'logic', 'and', 'or'],
        blocks: [
          Steps([
            ManualStep('Enter BASE-N mode.', 'MODE 4'),
            ManualStep(
              'x² DEC, x^□ HEX, log BIN, ln OCT choose the number system.',
            ),
            ManualStep('Hex digits A–F are on (−) °′″ hyp sin cos tan.'),
            ManualStep(
              'SHIFT 3: and, or, xor, xnor, Not, Neg; ▼ for d h b o prefixes.',
            ),
          ]),
          Example(
            title: '11₂ + 1₂',
            setup: 'MODE 4',
            keys: 'log 11 + 1 =',
            result: '0000000000000100',
            verify: '0000000000000100 [Bin]',
          ),
          Example(
            title: '15 × 37 shown in hexadecimal',
            setup: 'MODE 4',
            keys: 'x2 15 × 37 = ^',
            result: '0000022B',
            verify: '0000022B [Hex]',
          ),
          Tip(
            'Binary uses 16 bits, octal and hexadecimal 32 bits (two’s '
            'complement for negatives). Fractional parts are dropped.',
          ),
        ],
      ),
      ManualArticle(
        id: 'table-tb',
        title: 'Number tables (TABLE)',
        summary: 'Values of f(X) for X from Start to End.',
        audience: _tb,
        keywords: ['table', 'function', 'values', 'graph', 'f(x)'],
        blocks: [
          Steps([
            ManualStep('Enter TABLE mode.', 'MODE 7'),
            ManualStep('Type f(X) using ALPHA ) for X, then press =.'),
            ManualStep(
              'Answer Start?, End? and Step? with = (defaults 1, 5, 1).',
            ),
            ManualStep(
              '▲ ▼ scroll the table, ◀ ▶ choose the column, AC edits f(X).',
            ),
          ]),
          Example(
            title: 'X² + 1/2 for X = −1 … 1, step 0.5',
            keys: 'MODE 7 ALPHA ) x2 + 1 frac 2 = (-) 1 = 1 = 0.5 =',
            result: 'X: −1, −0.5, 0, 0.5, 1 → F(X): 1.5, 0.75, 0.5, 0.75, 1.5',
          ),
          Tip('At most 30 rows; more gives Insufficient MEM. X is changed.'),
        ],
      ),
      ManualArticle(
        id: 'matrix',
        title: 'Matrices (MAT)',
        summary: 'Up to 3 × 3: add, multiply, determinant, inverse.',
        audience: _two,
        requires: {CalcMode.mat},
        keywords: ['matrix', 'determinant', 'inverse', 'transpose'],
        blocks: [
          Steps([
            ManualStep('Enter MAT mode.', 'MODE MODE MODE 2'),
            ManualStep(
              'Set the size of MatA: Dim A, rows, columns.',
              'MAT 1 1 2 = 2 =',
            ),
            ManualStep('Type each element and press =.'),
            ManualStep('Det, Trn and Mat are on the MAT menu (SHIFT 4).'),
          ]),
        ],
      ),
      ManualArticle(
        id: 'matrix-tb',
        title: 'Matrices (MATRIX)',
        summary: 'Up to 3 × 3: +, −, ×, det, Trn, inverse, powers.',
        audience: _tb,
        keywords: ['matrix', 'determinant', 'inverse', 'transpose'],
        blocks: [
          Steps([
            ManualStep(
              'Enter MATRIX mode, pick MatA and a size (5 = 2×2).',
              'MODE 6 1 5',
            ),
            ManualStep(
              'Type each element and press = (fractions and √ allowed).',
            ),
            ManualStep(
              'AC goes to the calculation screen; SHIFT 4 has Dim, Data, MatA–C, MatAns, det and Trn.',
            ),
            ManualStep(
              'x⁻¹ inverts, x² squares, SHIFT x² cubes, SHIFT hyp is Abs.',
            ),
          ]),
          Example(
            title: 'det of [[2, 1], [1, 1]]',
            setup: 'MODE 6 1 5 2 = 1 = 1 = 1 = AC',
            keys: 'SHIFT 4 7 SHIFT 4 3 ) =',
            result: '1',
            verify: '1',
          ),
          Tip(
            'A matrix result opens the MatAns screen; pressing +, −, ×, ÷, '
            'x⁻¹ or x² there continues the calculation from MatAns.',
          ),
        ],
      ),
      ManualArticle(
        id: 'vector-tb',
        title: 'Vectors (VECTOR)',
        summary: '2-D and 3-D vectors: dot and cross products, length.',
        audience: _tb,
        keywords: ['vector', 'dot product', 'cross product', 'length', 'angle'],
        blocks: [
          Steps([
            ManualStep(
              'Enter VECTOR mode, pick VctA and its size (2 = 2-D).',
              'MODE 8 1 2',
            ),
            ManualStep('Type the elements with =, then AC.'),
            ManualStep(
              'SHIFT 5 has Dim, Data, VctA–C, VctAns and Dot; × is the cross product.',
            ),
          ]),
          Example(
            title: '(1, 2) • (3, 4)',
            setup: 'MODE 8 1 2 1 = 2 = SHIFT 5 1 2 2 3 = 4 = AC',
            keys: 'SHIFT 5 3 SHIFT 5 7 SHIFT 5 4 =',
            result: '11',
            verify: '11',
          ),
          Tip('Length: Abs (SHIFT hyp). Angle: cos⁻¹(A•B ÷ (|A|·|B|)).'),
        ],
      ),
    ],
  ),
  ManualChapter(
    id: 'setup',
    title: 'Setup and errors',
    icon: Icons.tune,
    articles: [
      ManualArticle(
        id: 'format',
        title: 'Fix, Sci and Norm',
        summary: 'Decimal places, significant digits and exponent display.',
        keywords: ['fix', 'sci', 'norm', 'decimal places', 'rounding'],
        blocks: [
          Para(
            'Fix shows a fixed number of decimal places, Sci a fixed number '
            'of significant digits; Norm 1 and Norm 2 decide when results '
            'switch to ×10 notation. The value inside keeps all 15 digits.',
          ),
          Example(
            title: '100 ÷ 7 with Fix 3',
            setup: 'MODE MODE MODE MODE MODE 1 3',
            keys: '100 ÷ 7 =',
            result: '14.286',
            verify: '14.286',
            only: _two,
          ),
          Example(
            title: '100 ÷ 7 with Fix 3',
            setup: 'SHIFT MODE 6 3',
            keys: '100 ÷ 7 SHIFT =',
            result: '14.286',
            verify: '14.286',
            only: _tb,
          ),
        ],
      ),
      ManualArticle(
        id: 'errors',
        title: 'Error messages',
        summary: 'Math, Syntax, Stack, Dimension and other errors.',
        keywords: ['error', 'math error', 'syntax error', 'stack'],
        blocks: [
          Para(
            'Math ERROR: a value is out of range or impossible (such as '
            'dividing by zero). Syntax ERROR: the calculation is not written '
            'correctly. Stack ERROR: too complicated, split it up. Dimension '
            'ERROR: matrix or vector sizes do not fit.',
          ),
          Steps([
            ManualStep(
              'Go back to the calculation with the cursor at the problem.',
              '<',
            ),
            ManualStep('Or clear everything.', 'AC'),
          ]),
        ],
      ),
      ManualArticle(
        id: 'reset',
        title: 'Reset',
        summary: 'Clear memories or return to the factory setup.',
        keywords: ['reset', 'clear', 'clr', 'factory', 'all'],
        blocks: [
          Para(
            'Two-line models: SHIFT MODE, then 1 (memories), 2 (setup) or 3 '
            '(all). Textbook models: SHIFT 9, then 1 Setup, 2 Memory or 3 '
            'All, and = to confirm. Menu ▸ Settings ▸ Reset calculator does '
            'the same for the model in use.',
          ),
        ],
      ),
    ],
  ),
];

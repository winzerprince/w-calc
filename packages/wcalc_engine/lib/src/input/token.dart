/// What a token is, for the evaluator.
enum TokKind {
  digit,
  point,
  exp,
  binary,

  /// Type B function: key first, then value (sin, √, log, (−) …).
  prefix,

  /// Type A function: value first, then key (x², x⁻¹, x!, °/ʳ/ᵍ …).
  postfix,
  openParen,
  closeParen,

  /// Ans, Ran#: a value read from memory / generated.
  operand,

  /// π, e: constants (implied multiplication like memory names).
  constant,

  /// Memory / variable names A–F, M, X, Y.
  variable,

  /// `:` between statements of a multi-statement.
  separator,

  /// Marks inside number literals: fraction `┘` (a b/c) and sexagesimal `°`.
  literalMark,

  /// `%` (SHIFT =) at the end of a percent calculation.
  percent,

  /// Argument separator inside function calls.
  comma,

  /// Function with parenthesised arguments: Pol(, Rec(, ∫(, d/dx(.
  function,

  /// `=` inside CALC / SOLVE expressions (ALPHA CALC).
  equation,

  /// CMPLX result-format commands at the end of an expression (▶r∠θ, ▶a+bi).
  formatCommand,

  /// `;` before a data frequency (SD/REG data input).
  dataSep,

  /// BASE mode: hexadecimal digits A-F.
  hexDigit,

  /// BASE mode: number-system prefix of one literal (d h b o).
  basePrefix,
}

/// One input step on the upper line. Each key press inserts one token, so
/// DEL/INS/cursor work on whole tokens ("sin " is one step), like the device.
enum Tok {
  d0('0', TokKind.digit),
  d1('1', TokKind.digit),
  d2('2', TokKind.digit),
  d3('3', TokKind.digit),
  d4('4', TokKind.digit),
  d5('5', TokKind.digit),
  d6('6', TokKind.digit),
  d7('7', TokKind.digit),
  d8('8', TokKind.digit),
  d9('9', TokKind.digit),
  point('.', TokKind.point),
  exp('E', TokKind.exp),

  add('+', TokKind.binary),
  subtract('-', TokKind.binary),
  multiply('×', TokKind.binary),
  divide('÷', TokKind.binary),
  power('^', TokKind.binary),
  xRoot('ˣ√', TokKind.binary),
  nPr('P', TokKind.binary),
  nCr('C', TokKind.binary),

  negative('-', TokKind.prefix),
  sin('sin ', TokKind.prefix),
  cos('cos ', TokKind.prefix),
  tan('tan ', TokKind.prefix),
  asin('sin⁻¹ ', TokKind.prefix),
  acos('cos⁻¹ ', TokKind.prefix),
  atan('tan⁻¹ ', TokKind.prefix),
  sinh('sinh ', TokKind.prefix),
  cosh('cosh ', TokKind.prefix),
  tanh('tanh ', TokKind.prefix),
  asinh('sinh⁻¹ ', TokKind.prefix),
  acosh('cosh⁻¹ ', TokKind.prefix),
  atanh('tanh⁻¹ ', TokKind.prefix),
  log('log ', TokKind.prefix),
  ln('ln ', TokKind.prefix),
  tenPow('10^', TokKind.prefix),
  ePow('e^', TokKind.prefix),
  sqrt('√', TokKind.prefix),
  cbrt('³√', TokKind.prefix),
  rnd('Rnd ', TokKind.prefix),

  square('²', TokKind.postfix),
  cube('³', TokKind.postfix),
  reciprocal('⁻¹', TokKind.postfix),
  factorial('!', TokKind.postfix),
  degMark('°', TokKind.postfix),
  radMark('ʳ', TokKind.postfix),
  graMark('ᵍ', TokKind.postfix),

  openParen('(', TokKind.openParen),
  closeParen(')', TokKind.closeParen),
  ans('Ans', TokKind.operand),
  ran('Ran#', TokKind.operand),
  pi('π', TokKind.constant),
  e('e', TokKind.constant),
  varA('A', TokKind.variable),
  varB('B', TokKind.variable),
  varC('C', TokKind.variable),
  varD('D', TokKind.variable),
  varE('E', TokKind.variable),
  varF('F', TokKind.variable),
  varM('M', TokKind.variable),
  varX('X', TokKind.variable),
  varY('Y', TokKind.variable),
  colon(':', TokKind.separator),
  fracSep('┘', TokKind.literalMark),
  dms('°', TokKind.literalMark),
  percent('%', TokKind.percent),
  engT('T', TokKind.postfix),
  engG('G', TokKind.postfix),
  engMega('M', TokKind.postfix),
  engKilo('k', TokKind.postfix),
  engMilli('m', TokKind.postfix),
  engMicro('μ', TokKind.postfix),
  engNano('n', TokKind.postfix),
  engPico('p', TokKind.postfix),
  engFemto('f', TokKind.postfix),
  comma(',', TokKind.comma),
  pol('Pol(', TokKind.function),
  rec('Rec(', TokKind.function),
  integral('∫(', TokKind.function),
  eqSign('=', TokKind.equation),
  imagUnit('i', TokKind.constant),
  angle('∠', TokKind.binary),
  cAbs('Abs ', TokKind.prefix),
  cArg('arg ', TokKind.prefix),
  conjg('Conjg ', TokKind.prefix),
  toPolar('▶r∠θ', TokKind.formatCommand),
  toRect('▶a+bi', TokKind.formatCommand),
  freqSep(';', TokKind.dataSep),
  hexA('A', TokKind.hexDigit),
  hexB('B', TokKind.hexDigit),
  hexC('C', TokKind.hexDigit),
  hexD('D', TokKind.hexDigit),
  hexE('E', TokKind.hexDigit),
  hexF('F', TokKind.hexDigit),
  baseD('d', TokKind.basePrefix),
  baseH('h', TokKind.basePrefix),
  baseB('b', TokKind.basePrefix),
  baseO('o', TokKind.basePrefix),
  logicAnd(' and ', TokKind.binary),
  logicOr(' or ', TokKind.binary),
  logicXor(' xor ', TokKind.binary),
  logicXnor(' xnor ', TokKind.binary),
  logicNot('Not ', TokKind.prefix),
  logicNeg('Neg ', TokKind.prefix),
  // MAT / VCT variables and functions.
  matA('MatA', TokKind.operand),
  matB('MatB', TokKind.operand),
  matC('MatC', TokKind.operand),
  matAns('MatAns', TokKind.operand),
  vctA('VctA', TokKind.operand),
  vctB('VctB', TokKind.operand),
  vctC('VctC', TokKind.operand),
  vctAns('VctAns', TokKind.operand),
  det('Det ', TokKind.prefix),
  trn('Trn ', TokKind.prefix),
  dot('•', TokKind.binary),
  // SD/REG statistics values (S-SUM / S-VAR) and estimates; x̄ ȳ x̂ ŷ use
  // private-use characters drawn by the LCD font.
  statSumX2('Σx²', TokKind.operand),
  statSumX('Σx', TokKind.operand),
  statN('n', TokKind.operand),
  statSumY2('Σy²', TokKind.operand),
  statSumY('Σy', TokKind.operand),
  statSumXY('Σxy', TokKind.operand),
  statSumX3('Σx³', TokKind.operand),
  statSumX2Y('Σx²y', TokKind.operand),
  statSumX4('Σx⁴', TokKind.operand),
  statMeanX('\uE000', TokKind.operand),
  statSigmaX('xσn', TokKind.operand),
  statSampleX('xσn-1', TokKind.operand),
  statMeanY('\uE001', TokKind.operand),
  statSigmaY('yσn', TokKind.operand),
  statSampleY('yσn-1', TokKind.operand),
  regA('A', TokKind.operand),
  regB('B', TokKind.operand),
  regC('C', TokKind.operand),
  regR('r', TokKind.operand),
  estX('\uE002', TokKind.postfix),
  estX1('\uE0021', TokKind.postfix),
  estX2('\uE0022', TokKind.postfix),
  estY('\uE003', TokKind.postfix),
  toT('▶t', TokKind.postfix),
  distP('P(', TokKind.function),
  distQ('Q(', TokKind.function),
  distR('R(', TokKind.function),
  derivative('d/dx(', TokKind.function),
  // Textbook-display models.
  fracDiv('⌟', TokKind.binary),
  sigma('Σ(', TokKind.function),
  logBase('log(', TokKind.function),
  ranInt('RanInt#(', TokKind.function),
  // Scientific constants (CONST 01-40) and metric conversions (CONV 01-40).
  const01('mₚ', TokKind.constant),
  const02('mₙ', TokKind.constant),
  const03('mₑ', TokKind.constant),
  const04('mμ', TokKind.constant),
  const05('a₀', TokKind.constant),
  const06('h', TokKind.constant),
  const07('μN', TokKind.constant),
  const08('μB', TokKind.constant),
  const09('ℏ', TokKind.constant),
  const10('α', TokKind.constant),
  const11('rₑ', TokKind.constant),
  const12('λc', TokKind.constant),
  const13('γₚ', TokKind.constant),
  const14('λcₚ', TokKind.constant),
  const15('λcₙ', TokKind.constant),
  const16('R∞', TokKind.constant),
  const17('u', TokKind.constant),
  const18('μₚ', TokKind.constant),
  const19('μₑ', TokKind.constant),
  const20('μₙ', TokKind.constant),
  const21('μμ', TokKind.constant),
  const22('F', TokKind.constant),
  const23('e', TokKind.constant),
  const24('NA', TokKind.constant),
  const25('k', TokKind.constant),
  const26('Vm', TokKind.constant),
  const27('R', TokKind.constant),
  const28('C₀', TokKind.constant),
  const29('C₁', TokKind.constant),
  const30('C₂', TokKind.constant),
  const31('σ', TokKind.constant),
  const32('ε₀', TokKind.constant),
  const33('μ₀', TokKind.constant),
  const34('Φ₀', TokKind.constant),
  const35('g', TokKind.constant),
  const36('G₀', TokKind.constant),
  const37('Z₀', TokKind.constant),
  const38('t', TokKind.constant),
  const39('G', TokKind.constant),
  const40('atm', TokKind.constant),
  conv01('in▶cm', TokKind.postfix),
  conv02('cm▶in', TokKind.postfix),
  conv03('ft▶m', TokKind.postfix),
  conv04('m▶ft', TokKind.postfix),
  conv05('yd▶m', TokKind.postfix),
  conv06('m▶yd', TokKind.postfix),
  conv07('mile▶km', TokKind.postfix),
  conv08('km▶mile', TokKind.postfix),
  conv09('n mile▶m', TokKind.postfix),
  conv10('m▶n mile', TokKind.postfix),
  conv11('acre▶m²', TokKind.postfix),
  conv12('m²▶acre', TokKind.postfix),
  conv13('gal(US)▶ℓ', TokKind.postfix),
  conv14('ℓ▶gal(US)', TokKind.postfix),
  conv15('gal(UK)▶ℓ', TokKind.postfix),
  conv16('ℓ▶gal(UK)', TokKind.postfix),
  conv17('pc▶km', TokKind.postfix),
  conv18('km▶pc', TokKind.postfix),
  conv19('km/h▶m/s', TokKind.postfix),
  conv20('m/s▶km/h', TokKind.postfix),
  conv21('oz▶g', TokKind.postfix),
  conv22('g▶oz', TokKind.postfix),
  conv23('lb▶kg', TokKind.postfix),
  conv24('kg▶lb', TokKind.postfix),
  conv25('atm▶Pa', TokKind.postfix),
  conv26('Pa▶atm', TokKind.postfix),
  conv27('mmHg▶Pa', TokKind.postfix),
  conv28('Pa▶mmHg', TokKind.postfix),
  conv29('hp▶kW', TokKind.postfix),
  conv30('kW▶hp', TokKind.postfix),
  conv31('kgf/cm²▶Pa', TokKind.postfix),
  conv32('Pa▶kgf/cm²', TokKind.postfix),
  conv33('kgf•m▶J', TokKind.postfix),
  conv34('J▶kgf•m', TokKind.postfix),
  conv35('lbf/in²▶kPa', TokKind.postfix),
  conv36('kPa▶lbf/in²', TokKind.postfix),
  conv37('°F▶°C', TokKind.postfix),
  conv38('°C▶°F', TokKind.postfix),
  conv39('J▶cal', TokKind.postfix),
  conv40('cal▶J', TokKind.postfix);

  const Tok(this.text, this.kind);

  /// Characters shown on the LCD.
  final String text;
  final TokKind kind;

  static const digits = [d0, d1, d2, d3, d4, d5, d6, d7, d8, d9];

  /// CONST 01-40 tokens in number order.
  static List<Tok> get constants => [
    for (final t in values)
      if (t.name.startsWith('const')) t,
  ];

  /// CONV 01-40 tokens in number order.
  static List<Tok> get conversions => [
    for (final t in values)
      if (t.name.startsWith('conv')) t,
  ];

  /// Digit value, or null.
  int? get digit => kind == TokKind.digit ? index - d0.index : null;
}

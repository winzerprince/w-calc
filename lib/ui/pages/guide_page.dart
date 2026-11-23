import 'package:flutter/material.dart';

import 'page_scaffold.dart';

/// One topic of the built-in user guide (original W-Calc text).
class GuideTopic {
  const GuideTopic(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

const guideTopics = [
  GuideTopic('Getting started', [
    'Type a calculation the way you would write it, then press =. The top line shows what you typed, the bottom line the result.',
    'AC clears the current calculation. DEL deletes the character under the cursor; SHIFT DEL switches to insert mode.',
    '◀ and ▶ move the cursor. Right after a result, ◀ lets you edit the calculation you just did.',
    'Coloured labels above a key are its second functions: orange with SHIFT, red with ALPHA. Purple, blue and green labels work in the CMPLX, SD/REG and BASE modes.',
    'Menu ▸ Calculator model switches between Scientific Plus (every mode) and Scientific Basic (calculations, statistics and regression). Your memories and data stay.',
  ]),
  GuideTopic('Modes and setup (MODE)', [
    'Press MODE repeatedly to page through: COMP / CMPLX, SD / REG / BASE, EQN / MAT / VCT, angle unit, display format and Disp. Press the number under an option to choose it. After the last page MODE returns to the calculation.',
    'Fix shows a fixed number of decimal places, Sci a fixed number of significant digits, Norm 1 / Norm 2 choose when results switch to exponential form.',
    'On the Disp page: EngON shows engineering symbols (k, m, μ …), ab/c or d/c chooses mixed or improper fractions, Dot / Comma chooses the decimal mark. ▶ on the Disp page adjusts the LCD contrast.',
  ]),
  GuideTopic('Memories', [
    'Ans always holds the last result. Pressing an operator right after a result continues from Ans.',
    'SHIFT RCL (STO) followed by a letter key stores the current value in A–F, M, X or Y. RCL followed by the letter shows it; ALPHA followed by the letter types the name into a calculation.',
    'M+ adds the result to memory M, SHIFT M+ subtracts it. The M indicator shows while M is not zero.',
    '▲ and ▼ scroll through earlier calculations. SHIFT ▲ copies the shown calculation and all later ones into one line separated by colons; ALPHA ∫dx types a colon yourself.',
    'SHIFT MODE (CLR) clears memories (Mcl), the setup (Mode) or everything (All). Memories survive closing the app.',
  ]),
  GuideTopic('Fractions, degrees and percent', [
    'a b/c separates whole number, numerator and denominator: 3 a b/c 1 a b/c 4 is three and a quarter. a b/c on a result switches between fraction and decimal, SHIFT a b/c between mixed and improper.',
    '°′″ enters degrees, minutes and seconds (2 °′″ 30 °′″). SHIFT °′″ shows a decimal result in degrees-minutes-seconds.',
    'SHIFT = (%) works out percentages: 1500 × 12 % gives 12 % of 1500; 2500 × 15 % + adds 15 %.',
    'ENG and SHIFT ENG move the decimal point in steps of three (engineering notation).',
  ]),
  GuideTopic('Functions', [
    'sin, cos and tan use the angle unit shown at the top (D, R or G). SHIFT gives the inverse functions; press hyp first for hyperbolic ones.',
    'Functions such as √, log and sin apply to the value that follows them; x², x⁻¹ and x! apply to the value before them.',
    'SHIFT Ans (DRG▸) marks a value as degrees, radians or grads and converts it to the current unit.',
    'CONST followed by two digits inserts one of 40 scientific constants; SHIFT CONST (CONV) followed by two digits converts units (for example 38 converts °C to °F).',
    'SHIFT + (Pol) and SHIFT − (Rec) convert between rectangular and polar coordinates; the second result goes to F and the first also to E.',
  ]),
  GuideTopic('Calculus, CALC and SOLVE', [
    '∫dx expression , a , b , n ) integrates from a to b using 2ⁿ intervals (n may be left out). SHIFT ∫dx (d/dx) expression , a ) differentiates at a. Use ALPHA ) to type X.',
    'CALC asks for the value of each variable in the expression, then shows the result; press CALC again to try other values.',
    'SOLVE (SHIFT CALC) finds a value of a variable that makes the expression zero (or both sides of = equal). Choose the variable with ▲ ▼, type a starting guess, then press SHIFT CALC.',
  ]),
  GuideTopic('Complex numbers (CMPLX)', [
    'ENG types i, SHIFT (−) types ∠ for polar input (2 ∠ 45). SHIFT = (Re⇔Im) switches between the real and imaginary parts of a result.',
    'SHIFT + (▸r∠θ) or SHIFT − (▸a+bi) at the end of a calculation chooses the result form. Abs, arg and Conjg are on the SHIFT ) ( , keys.',
  ]),
  GuideTopic('Statistics (SD and REG)', [
    'Clear old data with SHIFT MODE 1 =. Enter each value and press M+ (DT); in REG mode type x , y then DT. SHIFT , (;) adds a frequency.',
    'SHIFT 1 (S-SUM) and SHIFT 2 (S-VAR) insert sums, means, standard deviations, regression coefficients and estimates into calculations. ▶ pages through more items.',
    '▲ ▼ show the entered data; type a new value and press = to change it, or SHIFT M+ to delete it. In SD mode SHIFT 3 (DISTR) gives the normal distribution P, Q, R and ▸t.',
  ]),
  GuideTopic('Number systems (BASE)', [
    'x², ^, log and ln switch between decimal, hexadecimal, binary and octal (d, h, b, o shown on the right). The keys (−) to tan type A to F.',
    'x⁻¹ (LOGIC) pages through And, Or, Xnor, Xor, Not, Neg and the d h b o prefixes for single values. Calculations use 32-bit whole numbers.',
  ]),
  GuideTopic('Equations, matrices and vectors', [
    'EQN solves 2 or 3 simultaneous equations, or quadratic and cubic equations (press ▶ for Degree). Enter each coefficient and press =; then ▲ ▼ show the solutions.',
    'MAT: SHIFT 4 Dim sets a matrix size, Edit changes elements, Mat inserts MatA … MatAns. Use +, −, ×, x⁻¹, x², x³, Det, Trn and Abs.',
    'VCT: SHIFT 5 works the same for vectors; Dot is on the second page, × gives the cross product and Abs the length.',
  ]),
  GuideTopic('Errors', [
    'Math ERROR: a result or input is out of range, or impossible (such as dividing by zero). Syntax ERROR: the calculation is not written correctly. Stack ERROR: the calculation is too complex. Dim ERROR: matrix or vector sizes do not match.',
    'Press ◀ or ▶ to go back to the calculation with the cursor at the problem, or AC to clear it.',
  ]),
];

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuPageScaffold(
      title: 'User guide',
      children: [
        for (final topic in guideTopics)
          ExpansionTile(
            title: Text(
              topic.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [for (final p in topic.paragraphs) PageText(p)],
          ),
      ],
    );
  }
}

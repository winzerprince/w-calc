/// Matrix (up to 3×3) and vector (2 or 3 elements) arithmetic for MAT / VCT.
library;

import 'dec.dart';
import 'wide.dart';

typedef Mat = List<List<Dec>>;
typedef Vec = List<Dec>;

Never _dim() => throw const CalcError(CalcErrorKind.dim);
Never _math() => throw const CalcError(CalcErrorKind.math);

Wide _w(Dec d) => Wide.fromDec(d);

int _rows(Mat m) => m.length;
int _cols(Mat m) => m.first.length;

Mat _map2(Mat a, Mat b, Dec Function(Dec, Dec) f) {
  if (_rows(a) != _rows(b) || _cols(a) != _cols(b)) _dim();
  return [
    for (var r = 0; r < _rows(a); r++)
      [for (var c = 0; c < _cols(a); c++) f(a[r][c], b[r][c])],
  ];
}

Mat matAdd(Mat a, Mat b) => _map2(a, b, (x, y) => x + y);
Mat matSub(Mat a, Mat b) => _map2(a, b, (x, y) => x - y);

Mat matScale(Mat a, Dec k) => [
  for (final r in a) [for (final v in r) v * k],
];

Mat matMul(Mat a, Mat b) {
  if (_cols(a) != _rows(b)) _dim();
  return [
    for (var r = 0; r < _rows(a); r++)
      [
        for (var c = 0; c < _cols(b); c++)
          [for (var k = 0; k < _cols(a); k++) _w(a[r][k]) * _w(b[k][c])]
              .fold(Wide.zero, (s, v) => s + v)
              .toDec(),
      ],
  ];
}

Mat matTranspose(Mat a) => [
  for (var c = 0; c < _cols(a); c++)
    [for (var r = 0; r < _rows(a); r++) a[r][c]],
];

Mat matAbs(Mat a) => [
  for (final r in a) [for (final v in r) v.abs()],
];

Mat matNeg(Mat a) => [
  for (final r in a) [for (final v in r) -v],
];

Wide _det(List<List<Wide>> m) => switch (m.length) {
  1 => m[0][0],
  2 => m[0][0] * m[1][1] - m[0][1] * m[1][0],
  _ =>
    m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
        m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
        m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]),
};

List<List<Wide>> _wide(Mat a) => [
  for (final r in a) [for (final v in r) _w(v)],
];

Dec matDet(Mat a) {
  if (_rows(a) != _cols(a)) _dim();
  return _det(_wide(a)).toDec();
}

/// Inverse via adjugate / determinant (exact enough for 3×3 at 24 digits).
Mat matInverse(Mat a) {
  final n = _rows(a);
  if (n != _cols(a)) _dim();
  final w = _wide(a);
  final det = _det(w);
  if (det.isZero) _math();
  if (n == 1) {
    return [
      [(Wide.one / det).toDec()],
    ];
  }
  Wide minor(int r, int c) => _det([
    for (var i = 0; i < n; i++)
      if (i != r)
        [
          for (var j = 0; j < n; j++)
            if (j != c) w[i][j],
        ],
  ]);
  return [
    for (var r = 0; r < n; r++)
      [
        for (var c = 0; c < n; c++)
          // Transposed cofactor: element (r, c) uses minor (c, r).
          (((r + c).isEven ? minor(c, r) : -minor(c, r)) / det).toDec(),
      ],
  ];
}

// ---- vectors ----

void _same(Vec a, Vec b) {
  if (a.length != b.length) _dim();
}

Vec vecAdd(Vec a, Vec b) {
  _same(a, b);
  return [for (var i = 0; i < a.length; i++) a[i] + b[i]];
}

Vec vecSub(Vec a, Vec b) {
  _same(a, b);
  return [for (var i = 0; i < a.length; i++) a[i] - b[i]];
}

Vec vecScale(Vec a, Dec k) => [for (final v in a) v * k];

Vec vecNeg(Vec a) => [for (final v in a) -v];

Dec vecDot(Vec a, Vec b) {
  _same(a, b);
  var s = Wide.zero;
  for (var i = 0; i < a.length; i++) {
    s = s + _w(a[i]) * _w(b[i]);
  }
  return s.toDec();
}

/// Cross product; 2-element vectors are treated as (x, y, 0).
Vec vecCross(Vec a, Vec b) {
  _same(a, b);
  final x = [for (final v in a) _w(v), if (a.length == 2) Wide.zero];
  final y = [for (final v in b) _w(v), if (b.length == 2) Wide.zero];
  return [
    (x[1] * y[2] - x[2] * y[1]).toDec(),
    (x[2] * y[0] - x[0] * y[2]).toDec(),
    (x[0] * y[1] - x[1] * y[0]).toDec(),
  ];
}

Dec vecAbs(Vec a) =>
    WideMath.sqrt(a.fold(Wide.zero, (s, v) => s + _w(v) * _w(v))).toDec();

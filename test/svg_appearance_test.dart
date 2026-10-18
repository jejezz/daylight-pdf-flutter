import 'dart:io';

import 'package:daylight_pdf/engine/annotations/annotation_specs.dart';
import 'package:daylight_pdf/engine/annotations/svg_appearance.dart';
import 'package:flutter_test/flutter_test.dart';

/// 페이지의 (100, 200) ~ (124, 224)에 놓이는 24pt 정사각형 주석 영역.
const PdfBox box = (left: 100, bottom: 200, right: 124, top: 224);

String? ap(String body, {String viewBox = '0 0 24 24', PdfBox rect = box, int color = 0xFF000000}) => svgToAppearance(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox">$body</svg>',
  rect: rect,
  currentColor: color,
);

List<List<double>> fills(String ops) => [
  for (final m in RegExp(r'([\d.]+) ([\d.]+) ([\d.]+) rg').allMatches(ops))
    [double.parse(m.group(1)!), double.parse(m.group(2)!), double.parse(m.group(3)!)],
];

void main() {
  group('shapes and coordinates', () {
    test('a rect lands inside the annotation box with y flipped (SVG y down → PDF y up)', () {
      expect(
        ap('<rect x="4" y="4" width="16" height="16" fill="#ff0000"/>'),
        'q 1 0 0 rg 104 220 m 120 220 l 120 204 l 104 204 l h f Q',
      );
    });

    test('the drawing is scaled to the box and centred, keeping its aspect ratio', () {
      // viewBox 10x20 → 24x24 박스: 배율 1.2, 가로로 가운데 (왼쪽 여백 6)
      expect(
        ap('<rect width="10" height="20" fill="#000"/>', viewBox: '0 0 10 20'),
        'q 0 0 0 rg 106 224 m 118 224 l 118 200 l 106 200 l h f Q',
      );
      // 박스가 2배면 배율도 2배
      expect(
        ap('<rect width="24" height="24" fill="#000"/>', rect: (left: 0, bottom: 0, right: 48, top: 48)),
        'q 0 0 0 rg 0 48 m 48 48 l 48 0 l 0 0 l h f Q',
      );
    });

    test('a viewBox that does not start at 0,0 is honoured', () {
      expect(
        ap('<rect x="10" y="10" width="4" height="4" fill="#000"/>', viewBox: '10 10 24 24'),
        'q 0 0 0 rg 100 224 m 104 224 l 104 220 l 100 220 l h f Q',
      );
    });

    test('circle, ellipse, line, polygon and polyline are drawn', () {
      expect(ap('<circle cx="12" cy="12" r="8"/>'), allOf(startsWith('q 0 0 0 rg 120 212 m'), endsWith('f Q')));
      expect(ap('<ellipse cx="12" cy="12" rx="8" ry="4"/>'), contains(' c '));
      expect(ap('<line x1="0" y1="0" x2="24" y2="24" stroke="#00ff00" stroke-width="2"/>'), contains('0 1 0 RG 2 w'));
      expect(ap('<polygon points="0,0 24,0 12,24" fill="#000"/>'), 'q 0 0 0 rg 100 224 m 124 224 l 112 200 l h f Q');
      expect(ap('<polyline points="0,0 24,0 12,24" fill="none" stroke="#000"/>'), endsWith('S Q'));
    });

    test('transforms compose from the outside in', () {
      // 바깥 translate(4,4) 안쪽 scale(2): 사각형(0,0,4,4)은 (4,4)~(12,12)
      expect(
        ap('<g transform="translate(4,4)"><rect width="4" height="4" fill="#000" transform="scale(2)"/></g>'),
        'q 0 0 0 rg 104 220 m 112 220 l 112 212 l 104 212 l h f Q',
      );
    });
  });

  group('paths', () {
    test('relative commands equal their absolute form, including implicit repeated pairs', () {
      expect(ap('<path d="M10 10 l5 0 0 5 z"/>'), ap('<path d="M10 10 L15 10 L15 15 Z"/>'));
    });

    test('H and V move along one axis, and extra pairs after M become lines', () {
      expect(ap('<path d="M0 0 H10 V10 H0 Z"/>'), ap('<path d="M0 0 L10 0 L10 10 L0 10 Z"/>'));
      expect(ap('<path d="M0 0 10 0 10 10 Z"/>'), ap('<path d="M0 0 L10 0 L10 10 Z"/>'));
    });

    test('quadratic curves become cubic ones', () {
      final out = ap('<path d="M0 0 Q12 24 24 0"/>')!;
      expect(out, contains(' c '));
      expect(out, isNot(contains(' q ')), reason: 'there is no quadratic operator in PDF paths');
    });

    test('a half-circle arc ends exactly at its end point and is split into curves', () {
      final out = ap('<path d="M4 12 A8 8 0 0 1 20 12"/>')!;
      expect(RegExp(r' c ?').allMatches(out).length, greaterThanOrEqualTo(2));
      expect(out, contains('120 212 c'), reason: 'the last curve ends at (20,12) → (120,212)');
    });

    test('the smooth shorthand S reflects the previous control point', () {
      final out = ap('<path d="M0 12 C4 0 8 0 12 12 S20 24 24 12"/>')!;
      // 두 번째 곡선의 첫 제어점 = 12 + (12-8) = 16, 12 + (12-0) = 24 → 116, 200
      expect(out, contains('116 200'));
    });

    test('a broken path stops at the error and keeps what was drawn before it', () {
      expect(ap('<path d="M0 0 L24 0 L"/>'), isNotNull);
      expect(ap('<path d="X"/>'), isNull);
    });
  });

  group('paint', () {
    test('fill defaults to black, stroke to none; fill-rule evenodd uses f*', () {
      expect(ap('<path d="M0 0 H24 V24 H0 Z M6 6 H18 V18 H6 Z" fill-rule="evenodd"/>'), endsWith('f* Q'));
      expect(ap('<rect width="24" height="24"/>'), startsWith('q 0 0 0 rg'));
    });

    test('stroke only draws S with the width scaled like the drawing', () {
      final out = ap(
        '<path d="M0 0L24 24" fill="none" stroke="#00ff00" stroke-width="2"/>',
        rect: (left: 0, bottom: 0, right: 48, top: 48),
      );
      expect(out, contains('0 1 0 RG 4 w'));
      expect(out, endsWith('S Q'));
    });

    test('fill and stroke together use B, and line cap/join are carried over', () {
      final out = ap(
        '<rect width="24" height="24" fill="#f00" stroke="#00f" stroke-linecap="round" stroke-linejoin="bevel"/>',
      )!;
      expect(out, contains('1 0 0 rg'));
      expect(out, contains('0 0 1 RG'));
      expect(out, contains('1 J 2 j'));
      expect(out, endsWith('B Q'));
    });

    test('currentColor takes the colour given by the caller', () {
      expect(ap('<rect width="24" height="24" fill="currentColor"/>', color: 0xFF0000FF), startsWith('q 0 0 1 rg'));
    });

    test('colour forms: short hex, rgb(), percentages, names, style attribute', () {
      expect(fills(ap('<rect width="1" height="1" fill="#0f0"/>')!), [
        [0, 1, 0],
      ]);
      expect(fills(ap('<rect width="1" height="1" fill="rgb(255,0,0)"/>')!), [
        [1, 0, 0],
      ]);
      expect(fills(ap('<rect width="1" height="1" fill="rgb(0%,100%,0%)"/>')!), [
        [0, 1, 0],
      ]);
      expect(fills(ap('<rect width="1" height="1" fill="blue"/>')!), [
        [0, 0, 1],
      ]);
      expect(fills(ap('<rect width="1" height="1" style="fill:#ff0000;stroke:none"/>')!), [
        [1, 0, 0],
      ]);
    });

    test('opacity is blended with white because the appearance has no room for alpha', () {
      expect(fills(ap('<rect width="1" height="1" fill="#000" fill-opacity="0.5"/>')!), [
        [0.5, 0.5, 0.5],
      ]);
      expect(fills(ap('<g opacity="0.5"><rect width="1" height="1" fill="#000"/></g>')!), [
        [0.5, 0.5, 0.5],
      ]);
    });

    test('fill="none" and display="none" draw nothing', () {
      expect(ap('<rect width="24" height="24" fill="none"/>'), isNull);
      expect(ap('<rect width="24" height="24" display="none"/>'), isNull);
    });
  });

  group('gradients', () {
    const red2blue =
        '<linearGradient id="g" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ff0000"/><stop offset="1" stop-color="#0000ff"/></linearGradient>';

    test('a linear gradient is clipped to its shape and drawn as bands from the first colour to the last', () {
      final out = ap('$red2blue<rect width="24" height="24" fill="url(#g)"/>')!;
      expect(out, contains(' W n '), reason: 'bands are clipped to the shape');
      final colors = fills(out);
      expect(colors.length, greaterThan(4), reason: 'a visible gradient needs several bands');
      expect(colors.first[0], greaterThan(0.9));
      expect(colors.first[2], lessThan(0.1), reason: 'starts red');
      expect(colors.last[2], greaterThan(0.9));
      expect(colors.last[0], lessThan(0.1), reason: 'ends blue');
      // 띠 색은 한 방향으로 매끄럽게 변한다
      for (var i = 1; i < colors.length; i++) {
        expect(colors[i][2], greaterThanOrEqualTo(colors[i - 1][2]));
      }
    });

    test('a flat gradient (same colour at both ends) needs only one band', () {
      const flat =
          '<linearGradient id="f"><stop offset="0" stop-color="#336699"/><stop offset="1" stop-color="#336699"/></linearGradient>';
      expect(fills(ap('$flat<rect width="24" height="24" fill="url(#f)"/>')!).length, 1);
    });

    test('userSpaceOnUse coordinates and gradientTransform are applied', () {
      // 사용자 공간에서 y 0→24 아래로 변하는 그라디언트: 위(y=0)는 빨강, 아래(y=24)는 파랑. 첫 띠가 위쪽(큰 PDF y)에 온다.
      final out = ap(
        '<linearGradient id="v" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="24">'
        '<stop offset="0" stop-color="#ff0000"/><stop offset="1" stop-color="#0000ff"/></linearGradient>'
        '<rect width="24" height="24" fill="url(#v)"/>',
      )!;
      final colors = fills(out);
      expect(colors.first[0], greaterThan(0.9));
      expect(colors.last[2], greaterThan(0.9));
    });

    test('stop opacity is blended with white, and href borrows stops from another gradient', () {
      final out = ap(
        '<linearGradient id="base"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000"/></linearGradient>'
        '<linearGradient id="g2" href="#base" x1="0" x2="1"/>'
        '<rect width="24" height="24" fill="url(#g2)"/>',
      )!;
      final colors = fills(out);
      expect(colors.first[0], greaterThan(0.9), reason: 'the transparent end becomes white');
      expect(colors.last[0], lessThan(0.1), reason: 'the opaque end stays black');
    });

    test('a radial gradient falls back to one average colour', () {
      final out = ap(
        '<radialGradient id="r"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#000000"/></radialGradient>'
        '<circle cx="12" cy="12" r="10" fill="url(#r)"/>',
      )!;
      final colors = fills(out);
      expect(colors.length, 1);
      expect(colors.single[0], inInclusiveRange(0.4, 0.6));
      expect(out, isNot(contains(' W n ')));
    });
  });

  group('what is left out or rejected', () {
    test('text, images, clip paths, masks and <use> are ignored, so an icon made only of them yields null', () {
      expect(ap('<text x="0" y="10">A</text>'), isNull);
      expect(ap('<image href="x.png" width="24" height="24"/>'), isNull);
      expect(ap('<defs><rect id="r" width="24" height="24"/></defs><use href="#r"/>'), isNull);
      expect(ap('<clipPath id="c"><rect width="24" height="24"/></clipPath>'), isNull);
    });

    test('shapes next to ignored elements are still drawn', () {
      expect(ap('<text>x</text><rect width="24" height="24"/>'), startsWith('q 0 0 0 rg'));
    });

    test('invalid XML, a non-svg root, a missing size or an empty box return null', () {
      expect(svgToAppearance('<svg', rect: box), isNull);
      expect(svgToAppearance('<html/>', rect: box), isNull);
      expect(
        svgToAppearance('<svg xmlns="http://www.w3.org/2000/svg"><rect width="1" height="1"/></svg>', rect: box),
        isNull,
      );
      expect(ap('<rect width="24" height="24"/>', rect: (left: 0, bottom: 0, right: 0, top: 0)), isNull);
    });

    test('width and height serve as the viewBox when there is none', () {
      expect(
        svgToAppearance(
          '<svg xmlns="http://www.w3.org/2000/svg" width="24px" height="24px"><rect width="24" height="24"/></svg>',
          rect: box,
        ),
        isNotNull,
      );
    });

    test('numbers are written plainly: no exponents, trailing zeros trimmed', () {
      final out = ap('<rect x="0.1" y="0.12345" width="1e-7" height="3" fill="#000"/>')!;
      expect(out, isNot(contains('e')));
      expect(out, contains('100.1 223.877'));
    });
  });

  group('the bundled note icon (assets/annotations/note_icon.svg)', () {
    final svg = File('assets/annotations/note_icon.svg').readAsStringSync();

    test('draws every shape of the sticker icon (shadow, border, paper, fold, outline, three lines)', () {
      final out = svgToAppearance(svg, rect: box)!;
      expect(fills(out).length, 8);
      expect(out, isNot(contains(' W n ')), reason: 'this icon has no gradients, so no clipping is needed');
      expect(out.length, lessThan(4000), reason: 'every note stores this once, so it stays small');
    });

    test('keeps its colours: pale yellow paper, orange lines and navy outline', () {
      final colors = fills(svgToAppearance(svg, rect: box)!);
      bool has(double r, double g, double b) =>
          colors.any((c) => (c[0] - r).abs() < 0.01 && (c[1] - g).abs() < 0.01 && (c[2] - b).abs() < 0.01);
      expect(has(1, 0.89, 0.522), isTrue, reason: '#ffe385 paper');
      expect(has(0.976, 0.722, 0.31), isTrue, reason: '#f9b84f orange');
      expect(has(0.251, 0.224, 0.431), isTrue, reason: '#40396e outline');
    });

    test('the translucent shadow becomes the light grey it would look like on white', () {
      final shadow = fills(svgToAppearance(svg, rect: box)!).first;
      expect(shadow[0], closeTo(0.65, 0.01));
    });

    test('fits inside its box (100x100 icon into 24pt): every point stays within the annotation rectangle', () {
      final out = svgToAppearance(svg, rect: box)!;
      for (final m in RegExp(r'([\d.]+) ([\d.]+) [mlc]\b').allMatches(out)) {
        final x = double.parse(m.group(1)!), y = double.parse(m.group(2)!);
        expect(x, inInclusiveRange(box.left - 0.5, box.right + 0.5));
        expect(y, inInclusiveRange(box.bottom - 0.5, box.top + 0.5));
      }
    });

    test('is deterministic', () {
      expect(svgToAppearance(svg, rect: box), svgToAppearance(svg, rect: box));
    });
  });
}

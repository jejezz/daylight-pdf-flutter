import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// 쪽 모양에 딱 맞는 썸네일: 칸 안에서 쪽 비율을 지켜 가운데에 놓고, 흰 바탕과 얇은 테두리를 쪽 크기만큼만 두른다
/// (pdfrx 기본 그림자는 쓰지 않는다). [rotation]을 주면 그 회전으로 보여 준다.
class PageThumbnail extends StatelessWidget {
  const PageThumbnail({super.key, required this.document, required this.pageNumber, this.rotation});

  final PdfDocument document;

  /// 1부터 센 쪽 번호.
  final int pageNumber;
  final PdfPageRotation? rotation;

  @override
  Widget build(BuildContext context) {
    final page = document.pages[pageNumber - 1];
    final effective = rotation ?? page.rotation;
    // page.width/height는 이 쪽의 기본 회전을 이미 반영한다. [rotation]이 다르면 90° 단위 차이만큼 가로세로가 바뀐다.
    final quarterTurnsDiff = (effective.index - page.rotation.index) & 3;
    final swap = quarterTurnsDiff.isOdd;
    final width = swap ? page.height : page.width;
    final height = swap ? page.width : page.height;
    return Center(
      child: AspectRatio(
        aspectRatio: width / height,
        child: PdfPageView(
          document: document,
          pageNumber: pageNumber,
          rotationOverride: rotation,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}

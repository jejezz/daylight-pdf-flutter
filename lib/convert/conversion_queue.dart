import 'package:flutter/foundation.dart';

import 'conversion_error.dart';

enum JobStatus { pending, running, done, failed }

/// 목록에서 아이콘을 고르는 데 쓰는 변환 종류.
enum JobKind { image, svg, ai, pdf, other }

/// 큐에서 도는 변환 한 건. [run]은 만든 파일 경로 목록을 돌려준다.
class ConversionJob {
  ConversionJob({required this.label, required this.run, this.kind = JobKind.other});

  final JobKind kind;

  /// 목록에 보일 이름 (원본 파일 이름 등).
  final String label;
  final Future<List<String>> Function() run;

  JobStatus status = JobStatus.pending;
  List<String> outputs = const [];
  ConversionException? error;
}

/// 변환을 하나씩 차례로 돌린다. 한 건이 실패해도 나머지는 계속한다.
class ConversionQueue extends ChangeNotifier {
  final _jobs = <ConversionJob>[];
  bool _running = false;

  List<ConversionJob> get jobs => List.unmodifiable(_jobs);
  bool get isRunning => _running;

  void add(ConversionJob job) {
    _jobs.add(job);
    notifyListeners();
    _drain();
  }

  void clearFinished() {
    _jobs.removeWhere((j) => j.status == JobStatus.done || j.status == JobStatus.failed);
    notifyListeners();
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final next = _jobs.where((j) => j.status == JobStatus.pending).firstOrNull;
        if (next == null) break;
        next.status = JobStatus.running;
        notifyListeners();
        try {
          next.outputs = await next.run();
          next.status = JobStatus.done;
        } on ConversionException catch (e) {
          next.error = e;
          next.status = JobStatus.failed;
        } catch (_) {
          next.error = ConversionException(ConversionErrorKind.cannotRead, fileName: next.label);
          next.status = JobStatus.failed;
        }
        notifyListeners();
      }
    } finally {
      _running = false;
      // 대기열이 비었음을 듣는 쪽에 알린다 (변환이 모두 끝난 뒤 안내를 띄우는 데 쓴다).
      notifyListeners();
    }
  }
}

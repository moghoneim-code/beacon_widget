import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

typedef BeaconEventHandler = void Function(String kind, Map<String, Object?> payload);
typedef StatusHandler = void Function(String message);

/// Watches [vmServiceOutFile] for the websocket address `flutter run
/// --vmservice-out-file=PATH` writes there, connects, and forwards every
/// `beacon.*` extension event to [onSelected] — `beacon.selected` for a
/// single tap, `beacon.selectedMany` for a broadcast selection stack
/// (PLAN.md §6). The event kind itself is passed through so the caller
/// decides what to do with each; new kinds don't need a change here.
///
/// The file's content is the raw `ws://...` address as a plain string, not
/// JSON (confirmed against `flutter_tools`' `writeVmServiceFile`) — no
/// parsing needed beyond reading and trimming it.
///
/// Reconnects automatically: the file changes on every `flutter run` (a new
/// port each time), and the URI stops working across a hot restart or an
/// app relaunch even when the file doesn't change (PLAN.md §4.4).
class VmClient {
  VmClient({required this.vmServiceOutFile, required this.onSelected, this.onStatus});

  final File vmServiceOutFile;
  final BeaconEventHandler onSelected;
  final StatusHandler? onStatus;

  StreamSubscription<FileSystemEvent>? _watchSub;
  VmService? _service;
  String? _connectedUri;
  Timer? _retryTimer;
  bool _stopped = false;

  Future<void> start() async {
    _status('Watching ${vmServiceOutFile.path} for the VM service address...');
    if (!vmServiceOutFile.parent.existsSync()) {
      vmServiceOutFile.parent.createSync(recursive: true);
    }
    unawaited(_tryConnectFromFile());
    _watchSub = vmServiceOutFile.parent.watch(events: FileSystemEvent.all).listen((FileSystemEvent event) {
      if (event.path == vmServiceOutFile.path) {
        unawaited(_tryConnectFromFile());
      }
    });
  }

  Future<void> stop() async {
    _stopped = true;
    _retryTimer?.cancel();
    await _watchSub?.cancel();
    await _service?.dispose();
  }

  /// Exercises the same path a `FileSystemEvent` triggers. Exposed only so
  /// tests can fire off several overlapping attempts without needing the
  /// platform to actually deliver duplicate filesystem events for one write
  /// (it does, in practice, which is what this guards against).
  @visibleForTesting
  Future<void> debugTryConnectFromFile() => _tryConnectFromFile();

  Future<void> _tryConnectFromFile() async {
    if (_stopped || !vmServiceOutFile.existsSync()) return;
    final String uri = vmServiceOutFile.readAsStringSync().trim();
    if (uri.isEmpty || uri == _connectedUri) return;
    await _connect(uri);
  }

  Future<void> _connect(String wsUri) async {
    // A single file write commonly fires more than one FileSystemEvent, and
    // each becomes a call to _tryConnectFromFile. Claim the URI here, before
    // the first `await`, so those overlapping calls see it's already taken
    // and skip instead of racing to open duplicate connections — Dart runs
    // this synchronous prefix to completion before any other stream
    // callback gets a turn.
    _connectedUri = wsUri;
    _status('Connecting to $wsUri ...');
    try {
      final VmService service = await vmServiceConnectUri(wsUri);
      if (_stopped) {
        await service.dispose();
        return;
      }
      _service = service;
      unawaited(service.onDone.then((_) => _handleDisconnect()));
      await service.streamListen(EventStreams.kExtension);
      service.onExtensionEvent.listen((Event event) {
        final String? kind = event.extensionKind;
        final Map<String, Object?>? data = event.extensionData?.data;
        if (kind != null && kind.startsWith('beacon.') && data != null) {
          onSelected(kind, data);
        }
      });
      _status('Connected.');
    } catch (e) {
      if (_connectedUri == wsUri) _connectedUri = null;
      _status('Connect failed: $e');
      _scheduleRetry();
    }
  }

  void _handleDisconnect() {
    if (_stopped) return;
    _status('Disconnected from the VM service — waiting for it to come back...');
    _service = null;
    _connectedUri = null;
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_stopped) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 2), _tryConnectFromFile);
  }

  void _status(String message) => onStatus?.call(message);
}

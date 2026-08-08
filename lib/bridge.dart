/// The desktop half of beacon: receives selections from a running app over
/// the Dart VM Service, writes them to `.ref/`, and copies a paste-ready
/// reference to the clipboard.
///
/// This library is deliberately **not** exported from `beacon_widget.dart`.
/// It runs on your development machine, not on the device — it reaches for
/// `dart:io` and `package:vm_service`, neither of which belongs in the
/// widget tree. Importing it from app code would be a mistake; the usual
/// entry point is the executable:
///
/// ```bash
/// dart run beacon_widget:bridge --vmservice-out-file=.ref/vm.json
/// ```
///
/// It's exposed as a library so the pieces stay testable, and so anyone
/// wanting to build a different front end (an IDE plugin, a daemon) can
/// reuse the transport rather than reimplement it.
library;

export 'src/bridge/clipboard.dart';
export 'src/bridge/formatter.dart';
export 'src/bridge/housekeeping.dart';
export 'src/bridge/vm_client.dart';
export 'src/bridge/writer.dart';

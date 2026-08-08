import 'dart:async';
import 'dart:io';

/// Deletes `sel-*` files older than [maxAge] from [refDir] — each tap
/// leaves a `.json`+`.png` pair behind, and nobody's going back to
/// reference a selection from an hour ago.
void pruneOldSelections(Directory refDir, {Duration maxAge = const Duration(hours: 1)}) {
  if (!refDir.existsSync()) return;
  final DateTime cutoff = DateTime.now().subtract(maxAge);
  for (final FileSystemEntity entity in refDir.listSync()) {
    if (entity is! File) continue;
    final String name = entity.uri.pathSegments.last;
    if (!name.startsWith('sel-')) continue;
    if (entity.statSync().modified.isBefore(cutoff)) {
      entity.deleteSync();
    }
  }
}

/// Re-runs [pruneOldSelections] every [interval] for as long as the
/// returned [Timer] is alive.
///
/// The bridge is meant to be left running for an entire dev session
/// (the README says so explicitly), but pruning only ran once, at startup —
/// so `.ref/` grew without bound for as long as the process stayed up, only
/// getting cleaned out on the *next* restart. A long session tapping
/// through a real app accumulates a `.json`+`.png` pair per tap; this
/// closes that gap by pruning on a timer instead of only once. Interval is
/// deliberately coarse: this is disk housekeeping racing nothing, not a
/// latency-sensitive path.
Timer schedulePeriodicPruning(
  Directory refDir, {
  Duration interval = const Duration(minutes: 10),
  Duration maxAge = const Duration(hours: 1),
}) {
  return Timer.periodic(interval, (_) => pruneOldSelections(refDir, maxAge: maxAge));
}

/// Warns, at startup, if [projectRoot]'s `.gitignore` doesn't mention
/// `.ref` — these are throwaway dev-tool scratch files, not something
/// meant to land in commits (PLAN.md §5.3). Returns null if all's well.
String? checkGitignore(Directory projectRoot) {
  final File gitignore = File('${projectRoot.path}/.gitignore');
  if (!gitignore.existsSync()) {
    return 'No .gitignore found in ${projectRoot.path} — add ".ref/" to it so selections don\'t get committed.';
  }
  final bool mentioned = gitignore
      .readAsStringSync()
      .split('\n')
      .map((String line) => line.trim())
      .any((String line) => line == '.ref' || line == '.ref/' || line == '/.ref' || line == '/.ref/');
  if (!mentioned) {
    return '.gitignore doesn\'t mention .ref/ — add it so selections don\'t get committed.';
  }
  return null;
}

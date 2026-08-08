import 'dart:io';

/// Shells out to the platform clipboard tool — `pbcopy`/`pbpaste` on macOS,
/// `clip`/PowerShell's `Get-Clipboard` on Windows, `xclip` on Linux. No
/// clipboard *package* — those need Accessibility grants, TCC prompts, or
/// notarization; a pipe to a system binary needs none of that (PLAN.md §5).
class Clipboard {
  const Clipboard();

  Future<String?> read() async {
    try {
      final ProcessResult result;
      if (Platform.isMacOS) {
        result = await Process.run('pbpaste', const <String>[]);
      } else if (Platform.isWindows) {
        result = await Process.run('powershell', const <String>['-NoProfile', '-Command', 'Get-Clipboard']);
      } else {
        result = await Process.run('xclip', const <String>['-selection', 'clipboard', '-o']);
      }
      return result.exitCode == 0 ? result.stdout as String : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> write(String text) async {
    try {
      final Process process;
      if (Platform.isMacOS) {
        process = await Process.start('pbcopy', const <String>[]);
      } else if (Platform.isWindows) {
        process = await Process.start('clip', const <String>[]);
      } else {
        process = await Process.start('xclip', const <String>['-selection', 'clipboard']);
      }
      process.stdin.write(text);
      await process.stdin.close();
      return await process.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

/// Writes [text] to the clipboard and reports what happened via [onStatus].
///
/// PLAN.md §5.2 offers two options for clipboard hygiene: restore the
/// previous contents ~150ms later, or document the overwrite loudly. The
/// first would undo the tool's entire purpose here — the whole point is
/// that the developer's next ⌘V, whenever they get to it, pastes what they
/// just selected — so this always takes the second option instead.
Future<bool> copyToClipboard(
  String text, {
  required void Function(String message) onStatus,
  Clipboard clipboard = const Clipboard(),
}) async {
  final String? previous = await clipboard.read();
  final bool ok = await clipboard.write(text);
  if (!ok) {
    onStatus('Could not copy to clipboard — is pbcopy/xclip/clip available on this system?');
    return false;
  }
  onStatus(
    previous == null || previous.trim().isEmpty
        ? 'Copied to clipboard.'
        : 'Copied to clipboard (replaced whatever was there before).',
  );
  return true;
}

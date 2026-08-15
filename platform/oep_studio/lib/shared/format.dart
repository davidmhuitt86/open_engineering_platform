/// Formats a [DateTime] as `YYYY-MM-DD HH:MM` (local time) — used
/// anywhere Studio displays a timestamp, without pulling in the
/// `intl` package for a single format.
String formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}

/// Formats a byte count as `B`/`KB`/`MB`/`GB` with one decimal place
/// above 1 KB — used for Source Material file sizes (Work Package 008
/// STUDIO-TASK-000016: "Display: ... Size").
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
}

/// "No linked candidates" / "1 linked candidate" / "2 linked candidates"
/// — used by the Evidence Browser (Work Package 009 STUDIO-TASK-000020:
/// "Display: ... Linked Candidate Count").
String formatLinkedCount(int count) {
  if (count == 0) return 'No linked candidates';
  return '$count linked candidate${count == 1 ? '' : 's'}';
}

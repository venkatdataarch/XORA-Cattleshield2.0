extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  String get toTitleCase {
    if (isEmpty) return this;
    return split(RegExp(r'[\s_-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.capitalize)
        .join(' ');
  }

  bool get isValidPhone {
    if (isEmpty) return false;
    final cleaned = replaceAll(RegExp(r'[\s\-\(\)+]'), '');
    return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
  }

  bool get isValidEmail {
    if (isEmpty) return false;
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(this);
  }

  String get initials {
    if (isEmpty) return '';
    final words = trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }

  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }
}

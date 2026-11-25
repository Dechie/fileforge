/// A small Markdown-to-HTML conversion for the LibreOffice PDF path.
///
/// Covers headings, paragraphs, lists, emphasis, inline code, and links.
/// It is not a full Markdown implementation.
String markdownToHtml(String markdown, {String title = 'Document'}) {
  final lines = markdown
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final body = StringBuffer();
  final paragraph = StringBuffer();
  var inUnordered = false;
  var inOrdered = false;

  void closeLists() {
    if (inUnordered) {
      body.writeln('</ul>');
      inUnordered = false;
    }
    if (inOrdered) {
      body.writeln('</ol>');
      inOrdered = false;
    }
  }

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    body.writeln('<p>${_inline(paragraph.toString().trim())}</p>');
    paragraph.clear();
  }

  for (final raw in lines) {
    final line = raw.trimRight();
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      flushParagraph();
      closeLists();
      continue;
    }

    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      closeLists();
      final level = heading.group(1)!.length;
      body.writeln('<h$level>${_inline(heading.group(2)!)}</h$level>');
      continue;
    }

    if (RegExp(r'^([-*_])\1{2,}$').hasMatch(trimmed)) {
      flushParagraph();
      closeLists();
      body.writeln('<hr>');
      continue;
    }

    final unordered = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
    if (unordered != null) {
      flushParagraph();
      if (inOrdered) {
        body.writeln('</ol>');
        inOrdered = false;
      }
      if (!inUnordered) {
        body.writeln('<ul>');
        inUnordered = true;
      }
      body.writeln('<li>${_inline(unordered.group(1)!)}</li>');
      continue;
    }

    final ordered = RegExp(r'^\d+[.)]\s+(.*)$').firstMatch(trimmed);
    if (ordered != null) {
      flushParagraph();
      if (inUnordered) {
        body.writeln('</ul>');
        inUnordered = false;
      }
      if (!inOrdered) {
        body.writeln('<ol>');
        inOrdered = true;
      }
      body.writeln('<li>${_inline(ordered.group(1)!)}</li>');
      continue;
    }

    closeLists();
    if (paragraph.isNotEmpty) paragraph.write(' ');
    paragraph.write(trimmed);
  }

  flushParagraph();
  closeLists();

  return '<!DOCTYPE html><html><head><meta charset="utf-8">'
      '<title>${_escape(title)}</title></head><body>$body</body></html>';
}

String _inline(String text) {
  final escaped = _escape(text);
  final withCode = escaped.replaceAllMapped(
    RegExp(r'`([^`]+)`'),
    (match) => '<code>${match.group(1)}</code>',
  );
  final withLinks = withCode.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)'),
    (match) => '<a href="${match.group(2)}">${match.group(1)}</a>',
  );
  final withBold = withLinks.replaceAllMapped(
    RegExp(r'\*\*([^*]+)\*\*|__([^_]+)__'),
    (match) => '<strong>${match.group(1) ?? match.group(2)}</strong>',
  );
  return withBold.replaceAllMapped(
    RegExp(r'\*([^*]+)\*|_([^_]+)_'),
    (match) => '<em>${match.group(1) ?? match.group(2)}</em>',
  );
}

String _escape(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

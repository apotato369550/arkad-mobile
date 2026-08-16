import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Color/style tokens [buildMarkdownWidgets] pulls from, so callers can
/// match the surrounding PDF section (see export_service.dart's
/// `_PdfColors`) without this file depending on that private class.
class PdfMarkdownTheme {
  const PdfMarkdownTheme({
    required this.baseStyle,
    required this.strongColor,
    required this.headingColor,
    required this.linkColor,
    required this.mutedColor,
    required this.ruleColor,
  });

  final pw.TextStyle baseStyle;
  final PdfColor strongColor;
  final PdfColor headingColor;
  final PdfColor linkColor;
  final PdfColor mutedColor;
  final PdfColor ruleColor;
}

const _headingSizeByLevel = {1: 15.0, 2: 13.5, 3: 12.0, 4: 11.0, 5: 10.5, 6: 10.5};

/// Renders AI-generated markdown (bold, headers, bullet/numbered lists,
/// tables, blockquotes) as PDF widgets, so saved-analysis text in the
/// export reads the same way it does on the Analysis screen (which uses
/// `flutter_markdown`) instead of showing raw `**`/`#` syntax.
List<pw.Widget> buildMarkdownWidgets(String source, PdfMarkdownTheme theme) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) return const [];

  final document = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
  final widgets = <pw.Widget>[];
  for (final node in document.parse(trimmed)) {
    _renderBlock(node, theme, widgets, indent: 0);
  }
  return widgets;
}

void _renderBlock(md.Node node, PdfMarkdownTheme theme, List<pw.Widget> out, {required double indent}) {
  if (node is md.Text) {
    if (node.text.trim().isNotEmpty) out.add(_paragraph([node], theme, indent));
    return;
  }
  if (node is! md.Element) return;

  final children = node.children ?? const <md.Node>[];
  final level = int.tryParse(node.tag.length == 2 && node.tag[0] == 'h' ? node.tag[1] : '');

  if (level != null) {
    out.add(_heading(children, theme, level, indent));
    return;
  }

  switch (node.tag) {
    case 'p':
      out.add(_paragraph(children, theme, indent));
      break;
    case 'ul':
      _renderList(node, theme, out, indent: indent, ordered: false);
      break;
    case 'ol':
      _renderList(node, theme, out, indent: indent, ordered: true);
      break;
    case 'blockquote':
      out.add(_blockquote(children, theme, indent));
      break;
    case 'hr':
      out.add(pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 8),
        height: 0.75,
        color: theme.ruleColor,
      ));
      break;
    case 'table':
      out.add(_table(node, theme, indent));
      break;
    case 'pre':
      out.add(_codeBlock(node, theme, indent));
      break;
    default:
      for (final child in children) {
        _renderBlock(child, theme, out, indent: indent);
      }
  }
}

pw.Widget _paragraph(List<md.Node> inline, PdfMarkdownTheme theme, double indent) {
  return pw.Padding(
    padding: pw.EdgeInsets.only(left: indent, bottom: 6),
    child: pw.RichText(text: pw.TextSpan(children: _inlineSpans(inline, theme.baseStyle, theme))),
  );
}

pw.Widget _heading(List<md.Node> inline, PdfMarkdownTheme theme, int level, double indent) {
  final style = theme.baseStyle.copyWith(
    fontSize: _headingSizeByLevel[level] ?? 10.5,
    fontWeight: pw.FontWeight.bold,
    color: theme.headingColor,
  );
  return pw.Padding(
    padding: pw.EdgeInsets.only(left: indent, top: level <= 2 ? 10 : 8, bottom: 4),
    child: pw.RichText(text: pw.TextSpan(children: _inlineSpans(inline, style, theme))),
  );
}

void _renderList(
  md.Element list,
  PdfMarkdownTheme theme,
  List<pw.Widget> out, {
  required double indent,
  required bool ordered,
}) {
  var index = int.tryParse(list.attributes['start'] ?? '1') ?? 1;

  for (final item in list.children ?? const <md.Node>[]) {
    if (item is! md.Element || item.tag != 'li') continue;

    final inline = <md.Node>[];
    final nestedLists = <md.Element>[];
    for (final child in item.children ?? const <md.Node>[]) {
      if (child is md.Element && (child.tag == 'ul' || child.tag == 'ol')) {
        nestedLists.add(child);
      } else if (child is md.Element && child.tag == 'p') {
        inline.addAll(child.children ?? const <md.Node>[]);
      } else {
        inline.add(child);
      }
    }

    final marker = ordered ? '$index.' : '•';
    out.add(
      pw.Padding(
        padding: pw.EdgeInsets.only(left: indent, bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 16,
              child: pw.Text(marker, style: theme.baseStyle.copyWith(fontWeight: pw.FontWeight.bold, color: theme.headingColor)),
            ),
            pw.Expanded(
              child: pw.RichText(text: pw.TextSpan(children: _inlineSpans(inline, theme.baseStyle, theme))),
            ),
          ],
        ),
      ),
    );

    for (final nested in nestedLists) {
      _renderList(nested, theme, out, indent: indent + 16, ordered: nested.tag == 'ol');
    }
    index++;
  }
}

pw.Widget _blockquote(List<md.Node> children, PdfMarkdownTheme theme, double indent) {
  final inner = <pw.Widget>[];
  for (final child in children) {
    _renderBlock(child, theme, inner, indent: 0);
  }
  return pw.Container(
    margin: pw.EdgeInsets.only(left: indent, bottom: 6),
    padding: const pw.EdgeInsets.only(left: 10),
    decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: theme.ruleColor, width: 2))),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: inner),
  );
}

pw.Widget _table(md.Element table, PdfMarkdownTheme theme, double indent) {
  List<String> headerRow = const [];
  final bodyRows = <List<String>>[];

  for (final section in table.children ?? const <md.Node>[]) {
    if (section is! md.Element) continue;
    if (section.tag == 'thead') {
      for (final row in section.children ?? const <md.Node>[]) {
        if (row is md.Element && row.tag == 'tr') {
          headerRow = _cellTexts(row);
          break;
        }
      }
    } else if (section.tag == 'tbody') {
      for (final row in section.children ?? const <md.Node>[]) {
        if (row is md.Element && row.tag == 'tr') bodyRows.add(_cellTexts(row));
      }
    }
  }

  if (headerRow.isEmpty && bodyRows.isEmpty) return pw.SizedBox();

  return pw.Padding(
    padding: pw.EdgeInsets.only(left: indent, bottom: 8),
    child: pw.TableHelper.fromTextArray(
      headers: headerRow.isEmpty ? null : headerRow,
      data: bodyRows,
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: theme.headingColor),
      cellStyle: theme.baseStyle.copyWith(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      border: null,
    ),
  );
}

List<String> _cellTexts(md.Element row) {
  return [
    for (final cell in row.children ?? const <md.Node>[])
      if (cell is md.Element) cell.textContent.trim(),
  ];
}

pw.Widget _codeBlock(md.Element pre, PdfMarkdownTheme theme, double indent) {
  return pw.Container(
    margin: pw.EdgeInsets.only(left: indent, bottom: 8),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: theme.ruleColor, width: 0.75)),
    child: pw.Text(
      pre.textContent.trimRight(),
      style: theme.baseStyle.copyWith(fontSize: 8.5, color: theme.mutedColor),
    ),
  );
}

List<pw.InlineSpan> _inlineSpans(List<md.Node> nodes, pw.TextStyle style, PdfMarkdownTheme theme) {
  final spans = <pw.InlineSpan>[];
  for (final node in nodes) {
    spans.addAll(_inlineNode(node, style, theme));
  }
  return spans;
}

List<pw.InlineSpan> _inlineNode(md.Node node, pw.TextStyle style, PdfMarkdownTheme theme) {
  if (node is md.Text) {
    return [pw.TextSpan(text: node.text, style: style)];
  }
  if (node is! md.Element) return const [];

  final children = node.children ?? const <md.Node>[];
  switch (node.tag) {
    case 'strong':
      return _inlineSpans(children, style.copyWith(fontWeight: pw.FontWeight.bold, color: theme.strongColor), theme);
    case 'em':
      return _inlineSpans(children, style.copyWith(fontStyle: pw.FontStyle.italic), theme);
    case 'code':
      return [pw.TextSpan(text: node.textContent, style: style.copyWith(color: theme.mutedColor))];
    case 'a':
      return _inlineSpans(children, style.copyWith(color: theme.linkColor, decoration: pw.TextDecoration.underline), theme);
    case 'del':
      return _inlineSpans(children, style.copyWith(decoration: pw.TextDecoration.lineThrough), theme);
    case 'br':
      return [pw.TextSpan(text: '\n', style: style)];
    default:
      return _inlineSpans(children, style, theme);
  }
}

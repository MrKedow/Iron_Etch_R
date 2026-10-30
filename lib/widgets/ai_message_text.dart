import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 轻量 AI 回复渲染器：即使模型泄漏 Markdown 符号，也能显示为清晰的标题与要点。
class AiMessageText extends StatelessWidget {
  final String text;
  final AppThemeSpec spec;
  final double fontSize;
  final bool selectable;

  const AiMessageText({
    super.key,
    required this.text,
    required this.spec,
    this.fontSize = 12.5,
    this.selectable = false,
  });

  static final RegExp _heading = RegExp(r'^#{1,6}\s*(.+?)\s*#*$');
  static final RegExp _boldOnly = RegExp(r'^\*\*(.+?)\*\*$');
  static final RegExp _bullet = RegExp(r'^(?:[-*•·]|—)\s+(.+)$');
  static final RegExp _numbered = RegExp(r'^(\d{1,2})[.)、]\s*(.+)$');
  static final RegExp _rule = RegExp(r'^(?:-{3,}|\*{3,}|_{3,})$');
  static final RegExp _fence = RegExp(r'^```.*$');

  @override
  Widget build(BuildContext context) {
    final blocks = _parse(text);
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      switch (block.type) {
        case _AiBlockType.gap:
          children.add(const SizedBox(height: 6));
          break;
        case _AiBlockType.heading:
          children.add(Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 9, bottom: 5),
            child: _richText(
              block.text,
              TextStyle(
                color: spec.primary,
                fontSize: fontSize + 2,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ));
          break;
        case _AiBlockType.bullet:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 7, right: 8),
                  decoration: BoxDecoration(
                    color: spec.primary.withValues(alpha: .72),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(child: _body(block.text)),
              ],
            ),
          ));
          break;
        case _AiBlockType.numbered:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 23,
                  child: Text(
                    '${block.level}.',
                    style: TextStyle(
                      color: spec.primary,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      height: 1.65,
                    ),
                  ),
                ),
                Expanded(child: _body(block.text)),
              ],
            ),
          ));
          break;
        case _AiBlockType.paragraph:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _body(block.text),
          ));
          break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _body(String value) {
    return _richText(
      value,
      TextStyle(
        color: spec.textPrimary,
        fontSize: fontSize,
        height: 1.65,
      ),
    );
  }

  Widget _richText(String value, TextStyle style) {
    final spans = _inlineSpans(value, style);
    if (selectable) {
      return SelectableText.rich(TextSpan(style: style, children: spans));
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }

  List<InlineSpan> _inlineSpans(String value, TextStyle style) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*([^*]+)\*\*|__([^_]+)__|`([^`]+)`');
    var cursor = 0;
    for (final match in pattern.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, match.start)));
      }
      if (match.group(1) != null || match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(1) ?? match.group(2),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ));
      } else {
        spans.add(TextSpan(
          text: match.group(3),
          style: TextStyle(
            color: spec.primary,
            fontWeight: FontWeight.w700,
          ),
        ));
      }
      cursor = match.end;
    }
    if (cursor < value.length) {
      spans.add(TextSpan(text: value.substring(cursor)));
    }
    return spans;
  }

  List<_AiBlock> _parse(String raw) {
    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', '  ');
    final blocks = <_AiBlock>[];
    for (var line in normalized.split('\n')) {
      var value = line.trim();
      if (_fence.hasMatch(value)) continue;
      if (value.startsWith('>')) value = value.substring(1).trim();
      if (value.isEmpty) {
        if (blocks.isNotEmpty && blocks.last.type != _AiBlockType.gap) {
          blocks.add(const _AiBlock(type: _AiBlockType.gap, text: ''));
        }
        continue;
      }
      if (_rule.hasMatch(value)) {
        if (blocks.isNotEmpty && blocks.last.type != _AiBlockType.gap) {
          blocks.add(const _AiBlock(type: _AiBlockType.gap, text: ''));
        }
        continue;
      }
      final heading = _heading.firstMatch(value);
      if (heading != null) {
        blocks.add(_AiBlock(
          type: _AiBlockType.heading,
          text: heading.group(1)!.trim(),
        ));
        continue;
      }
      final boldOnly = _boldOnly.firstMatch(value);
      if (boldOnly != null) {
        blocks.add(_AiBlock(
          type: _AiBlockType.heading,
          text: boldOnly.group(1)!.trim(),
        ));
        continue;
      }
      final bullet = _bullet.firstMatch(value);
      if (bullet != null) {
        blocks.add(_AiBlock(
          type: _AiBlockType.bullet,
          text: bullet.group(1)!.trim(),
        ));
        continue;
      }
      final numbered = _numbered.firstMatch(value);
      if (numbered != null) {
        blocks.add(_AiBlock(
          type: _AiBlockType.numbered,
          text: numbered.group(2)!.trim(),
          level: int.tryParse(numbered.group(1)!) ?? 1,
        ));
        continue;
      }
      blocks.add(_AiBlock(
        type: _AiBlockType.paragraph,
        text: value,
      ));
    }
    while (blocks.isNotEmpty && blocks.last.type == _AiBlockType.gap) {
      blocks.removeLast();
    }
    return blocks;
  }
}

enum _AiBlockType { heading, bullet, numbered, paragraph, gap }

class _AiBlock {
  final _AiBlockType type;
  final String text;
  final int level;

  const _AiBlock({
    required this.type,
    required this.text,
    this.level = 1,
  });
}

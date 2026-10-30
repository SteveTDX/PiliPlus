import 'package:PiliPlus/utils/global_data.dart';

/// 屏蔽关键词过滤器
///
/// 对视频的标题与标签（分区、tag 等）做不区分大小写的字面包含匹配，
/// 命中任意一个屏蔽关键词即隐藏该视频。
///
/// 使用字面匹配而非正则，避免关键词内容被当作表达式解析（防注入）。
abstract final class BlockKeywordFilter {
  static Set<String> get _keywords => GlobalData().blockKeywords;

  static bool get enabled => _keywords.isNotEmpty;

  static int get count => _keywords.length;

  /// 匹配单段文本（关键词同样小写化，确保含英文的关键词也能命中）
  static bool matchText(String? text) {
    if (!enabled || text == null || text.isEmpty) return false;
    final lower = text.toLowerCase();
    return _keywords.any((k) => lower.contains(k.toLowerCase()));
  }

  /// 匹配标题与若干标签
  static bool match(String? title, [Iterable<String?>? tags]) {
    if (!enabled) return false;
    if (matchText(title)) return true;
    if (tags != null) {
      for (final tag in tags) {
        if (matchText(tag)) return true;
      }
    }
    return false;
  }

  /// 匹配接口返回的原始条目，自动识别常见字段：
  /// 标题 `title`（去除 em 高亮标签），标签 `tname` / `tag` / `tags`，
  /// 以及 app 推荐 `args` 内的同名字段。
  static bool matchItem(Map item) {
    if (!enabled) return false;

    final title = item['title'];
    if (title is String && matchText(_stripHtml(title))) return true;

    if (_matchTagFields(item)) return true;

    final args = item['args'];
    if (args is Map && _matchTagFields(args)) return true;

    return false;
  }

  static bool _matchTagFields(Map item) {
    for (final key in const ['tname', 'tag', 'tags']) {
      final value = item[key];
      if (value is String) {
        if (matchText(value)) return true;
      } else if (value is List) {
        for (final e in value) {
          if (e is String) {
            if (matchText(e)) return true;
          } else if (e is Map && _matchTagFields(e)) {
            return true;
          }
        }
      } else if (value is Map && _matchTagFields(value)) {
        return true;
      }
    }
    return false;
  }

  static String _stripHtml(String str) =>
      str.replaceAll(RegExp('<[^>]*>'), '');
}

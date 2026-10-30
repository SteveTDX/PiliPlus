import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:PiliPlus/utils/global_data.dart';

/// 屏蔽用户过滤器
///
/// 对视频用户名称（UP 主名）做不区分大小写的字面包含匹配，
/// 命中任意一个屏蔽用户名称关键词即隐藏该用户的视频。
///
/// 使用字面匹配而非正则，避免关键词内容被当作表达式解析（防注入）。
abstract final class BlockUserFilter {
  static Set<String> get _keywords => GlobalData().blockUserNames;

  static bool get enabled => _keywords.isNotEmpty;

  static int get count => _keywords.length;

  /// 匹配单段用户名称
  static bool matchText(String? text) {
    if (!enabled || text == null || text.isEmpty) return false;
    final lower = text.toLowerCase();
    return _keywords.any(lower.contains);
  }

  /// 防御式匹配动态字段：仅当值确实为字符串时才比较
  static bool _matchField(Object? value) => value is String && matchText(value);

  /// 匹配接口返回的原始条目，自动识别常见用户名字段：
  /// `owner.name` / `owner.uname`（web 推荐、最热、相关视频），
  /// `args.up_name`（app 推荐），`author`（搜索结果），
  /// 以及 `up_name` / `uname`。
  static bool matchItem(Map item) {
    if (!enabled) return false;

    final owner = item['owner'];
    if (owner is Map) {
      if (_matchField(owner['name'])) return true;
      if (_matchField(owner['uname'])) return true;
    }

    final args = item['args'];
    if (args is Map) {
      if (_matchField(args['up_name'])) return true;
      if (_matchField(args['uname'])) return true;
    }

    if (_matchField(item['author'])) return true;
    if (_matchField(item['up_name'])) return true;
    if (_matchField(item['uname'])) return true;

    return false;
  }

  /// 匹配已解析的视频模型：`owner.name` 即视频卡片上显示的 UP 主名，
  /// 是屏蔽判断的权威来源（与 UI 显示完全一致）。
  static bool matchModel(Object? item) =>
      enabled && item is BaseVideoItemModel && matchText(item.owner.name);

  /// 屏蔽用户关键词变更后，就地重滤所有仍在内存中的列表数据并刷新界面，
  /// 使推荐流/热门等已加载列表立即生效，无需手动下拉刷新。
  static void refilterLoadedLists() {
    if (!enabled) return;
    for (final controller in CommonController.instances.toList()) {
      if (controller.isClosed) continue;
      final value = controller.loadingState.value;
      if (value is! Success) continue;
      final Object? response = value.response;
      if (response is! List) continue;
      final before = response.length;
      response.removeWhere(matchModel);
      if (response.length != before) {
        controller.loadingState.refresh();
      }
    }
  }
}

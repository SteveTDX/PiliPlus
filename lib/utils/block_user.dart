import 'dart:async';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:PiliPlus/utils/global_data.dart';

/// 屏蔽用户 / 白名单过滤器
///
/// 对视频用户名称（UP 主名）做不区分大小写的字面包含匹配：
/// 1. 黑名单优先：命中任意黑名单关键词即隐藏该用户的视频；
/// 2. 白名单次之：白名单非空时，仅黑名单未命中且用户名称
///    命中白名单关键词的视频才会显示（黑名单优先级高于白名单）。
///
/// 使用字面匹配而非正则，避免关键词内容被当作表达式解析（防注入）。
abstract final class BlockUserFilter {
  static Set<String> get _keywords => GlobalData().blockUserNames;

  static Set<String> get _whiteKeywords => GlobalData().whiteUserNames;

  /// 白名单是否启用（非空即启用）
  static bool get whitelistEnabled => _whiteKeywords.isNotEmpty;

  static bool get enabled => _keywords.isNotEmpty || whitelistEnabled;

  static int get count => _keywords.length;

  /// 名称是否命中关键词集合（不区分大小写的字面包含匹配）
  static bool _containsAny(String? text, Set<String> keywords) {
    if (text == null || text.isEmpty || keywords.isEmpty) return false;
    final lower = text.toLowerCase();
    return keywords.any((k) => lower.contains(k.toLowerCase()));
  }

  /// 匹配单段用户名称，返回 true 表示应隐藏：
  /// 黑名单命中 → 隐藏；白名单启用且未命中白名单 → 隐藏。
  /// （关键词同样小写化，确保含英文的关键词如 `小杨Johnson`
  /// 也能匹配 `小杨johnson`）
  static bool matchText(String? text) {
    if (_containsAny(text, _keywords)) return true;
    if (whitelistEnabled) return !_containsAny(text, _whiteKeywords);
    return false;
  }

  /// 匹配接口返回的原始条目，自动识别常见用户名字段：
  /// `owner.name` / `owner.uname`（web 推荐、最热、相关视频），
  /// `args.up_name`（app 推荐），`author`（搜索结果），
  /// 以及 `up_name` / `uname`。
  ///
  /// 这些字段是同一 UP 主名称的不同表示，任一字段命中黑名单即隐藏；
  /// 白名单启用时，任一字段命中白名单即可显示。
  static bool matchItem(Map item) {
    if (!enabled) return false;

    final names = <String>[];
    void collect(Object? value) {
      if (value is String && value.isNotEmpty) names.add(value);
    }

    final owner = item['owner'];
    if (owner is Map) {
      collect(owner['name']);
      collect(owner['uname']);
    }

    final args = item['args'];
    if (args is Map) {
      collect(args['up_name']);
      collect(args['uname']);
    }

    collect(item['author']);
    collect(item['up_name']);
    collect(item['uname']);

    // 黑名单优先级高于白名单：任一字段命中黑名单即隐藏
    if (_keywords.isNotEmpty && names.any(_containsBlack)) {
      return true;
    }
    // 白名单启用时：任一字段命中白名单才显示（无名称信息一律隐藏）
    if (whitelistEnabled) {
      return !names.any(_containsWhite);
    }
    return false;
  }

  static bool _containsBlack(String name) => _containsAny(name, _keywords);

  static bool _containsWhite(String name) => _containsAny(name, _whiteKeywords);

  /// 匹配已解析的视频模型：`owner.name` 即视频卡片上显示的 UP 主名，
  /// 是屏蔽/白名单判断的权威来源（与 UI 显示完全一致）。
  static bool matchModel(Object? item) =>
      enabled && item is BaseVideoItemModel && matchText(item.owner.name);

  /// 屏蔽/白名单关键词变更后重滤所有仍在内存中的列表数据并刷新界面。
  ///
  /// [reload] 用于白名单变更：就地过滤只能删除、无法恢复此前被白名单
  /// 隐藏的视频，因此额外触发重新拉取，保证放宽或清空白名单后列表能
  /// 完整恢复；黑名单变更沿用就地重滤，离线时也能立即生效。
  static void refilterLoadedLists({bool reload = false}) {
    final controllers = CommonController.instances.toList();
    _refilterInPlace(controllers);
    if (!reload) return;
    for (final controller in controllers) {
      if (controller.isClosed) continue;
      unawaited(controller.onRefresh());
    }
  }

  static void _refilterInPlace(List<CommonController> controllers) {
    if (!enabled) return;
    for (final controller in controllers) {
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

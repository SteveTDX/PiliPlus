import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/data.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/media.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/data.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 仅限收藏夹播放：加载并缓存当前账号全部收藏夹内的视频 id，
/// 供播放入口（PageUtils.toVideoPage）做放行校验。
///
/// 缓存按账号区分并有过期时间，避免切换账号后误放行，
/// 或开启功能后新收藏的视频因缓存陈旧被误拦截。
abstract final class FavOnlyService {
  static const Duration cacheTtl = Duration(minutes: 10);

  /// 收藏夹并发拉取路数。实测账号可能有 26 个收藏夹 / 40 次分页请求，
  /// 全串行会让首次点击视频等待过久；并发数保持保守以规避接口风控。
  static const int _concurrency = 5;

  /// 单个收藏夹最大页数，防止服务端 has_more 异常导致死循环。
  static const int _maxPagePerFolder = 50;

  static final Set<int> _favAids = {};
  static final Set<String> _favBvids = {};
  static bool _loaded = false;
  static int? _loadedMid;
  static DateTime? _loadedAt;
  static Future<bool>? _loading;

  static bool get isLoaded => _loaded;

  /// 清空缓存（关闭功能、切换账号或需要强制刷新时调用）
  static void invalidate() {
    _loaded = false;
    _loadedMid = null;
    _loadedAt = null;
    _favAids.clear();
    _favBvids.clear();
    _loading = null;
  }

  /// 重新加载收藏夹数据
  static Future<bool> reload() {
    invalidate();
    return _ensureLoaded();
  }

  /// 校验视频是否允许播放；数据未加载/已过期时会先加载（带 loading 提示）。
  /// 返回 false 表示不允许播放（fail-closed）。
  static Future<bool> checkAllowed({int? aid, String? bvid}) async {
    if (!_ensureIds(aid, bvid)) return false;
    if (!await _ensureLoaded()) return false;
    return isFav(aid: aid, bvid: bvid);
  }

  /// 数据已加载时的同步校验（未加载数据时视为不允许）
  static bool isFav({int? aid, String? bvid}) {
    if (!_loaded) return false;
    if (aid != null && _favAids.contains(aid)) return true;
    if (bvid != null && _favBvids.contains(bvid)) return true;
    return false;
  }

  static bool _ensureIds(int? aid, String? bvid) {
    if (aid == null && bvid == null) {
      SmartDialog.showToast('无法识别视频 id，已拦截播放');
      return false;
    }
    return true;
  }

  static Future<bool> _ensureLoaded() {
    // 账号变化后旧缓存立即失效，避免用 A 账号收藏夹放行 B 账号的视频
    if (_loaded && _loadedMid != Accounts.main.mid) invalidate();
    if (_loaded) {
      final at = _loadedAt;
      if (at == null || DateTime.now().difference(at) < cacheTtl) {
        return Future.value(true);
      }
      // 缓存过期：重新拉取，避免新收藏的视频被误拦截
      invalidate();
    }
    return _loading ??= _loadAll();
  }

  static Future<bool> _loadAll() async {
    SmartDialog.showLoading(msg: '正在获取收藏夹数据');
    String? msg;
    try {
      if (!Accounts.main.isLogin) {
        msg = '仅限收藏夹播放需先登录账号';
        return false;
      }
      final mid = Accounts.main.mid;

      final foldersRes = await FavHttp.allFavFolders(mid);
      final folders = switch (foldersRes) {
        Success<FavFolderData>(:final response) =>
          response.list ?? const <FavFolderInfo>[],
        _ => null,
      };
      if (folders == null) {
        msg = '获取收藏夹列表失败：$foldersRes';
        return false;
      }

      // 按批并发拉取收藏夹；单个收藏夹内部仍按 has_more 串行翻页。
      for (var i = 0; i < folders.length; i += _concurrency) {
        final end = i + _concurrency > folders.length
            ? folders.length
            : i + _concurrency;
        final results = await Future.wait(
          folders.sublist(i, end).map(_loadFolder),
        );
        for (final error in results) {
          if (error != null) {
            msg = error;
            return false;
          }
        }
      }

      _loaded = true;
      _loadedMid = mid;
      _loadedAt = DateTime.now();
      msg = _favAids.isEmpty
          ? '收藏夹内暂无视频，开启后无法播放任何视频'
          : '收藏夹校验就绪（${_favAids.length} 个视频）';
      return true;
    } catch (e) {
      msg = '获取收藏夹数据异常：$e';
      return false;
    } finally {
      _loading = null;
      // 统一关闭 loading 后再提示，避免 toast 被 loading 遮住
      SmartDialog.dismiss(status: SmartStatus.loading);
      final tip = msg;
      if (tip != null) SmartDialog.showToast(tip);
    }
  }

  /// 拉取单个收藏夹全部视频；返回 null 表示成功，否则返回错误信息。
  static Future<String?> _loadFolder(FavFolderInfo folder) async {
    int pn = 1;
    while (true) {
      final res = await FavHttp.userFavFolderDetail(
        mediaId: folder.id,
        pn: pn,
        ps: 20,
      );
      final data = switch (res) {
        Success<FavDetailData>(:final response) => response,
        _ => null,
      };
      if (data == null) {
        return '获取收藏内容失败：$res';
      }
      for (final media in data.medias ?? const <FavDetailItemModel>[]) {
        // 仅统计视频稿件（type == 2），排除番剧/文集/课程/合集等
        if (media.type == 2) {
          final id = media.id;
          if (id != null) _favAids.add(id);
          final bv = media.bvid;
          if (bv != null && bv.isNotEmpty) _favBvids.add(bv);
        }
      }
      if (data.hasMore != true) return null;
      pn++;
      if (pn > _maxPagePerFolder) {
        return '收藏夹分页异常（超过 $_maxPagePerFolder 页）：${folder.id}';
      }
    }
  }
}

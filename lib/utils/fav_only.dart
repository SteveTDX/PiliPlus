import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 仅限收藏夹播放：加载并缓存当前账号全部收藏夹内的视频 id，
/// 供播放入口（PageUtils.toVideoPage）做放行校验。
abstract final class FavOnlyService {
  static final Set<int> _favAids = {};
  static final Set<String> _favBvids = {};
  static bool _loaded = false;
  static Future<bool>? _loading;

  static bool get isLoaded => _loaded;

  /// 清空缓存（关闭功能或需要强制刷新时调用）
  static void invalidate() {
    _loaded = false;
    _favAids.clear();
    _favBvids.clear();
    _loading = null;
  }

  /// 重新加载收藏夹数据
  static Future<bool> reload() {
    invalidate();
    return _ensureLoaded();
  }

  /// 校验视频是否允许播放；数据未加载时会先加载（带 loading 提示）。
  /// 返回 false 表示不允许播放。
  static Future<bool> checkAllowed({int? aid, String? bvid}) async {
    if (!_ensureIds(aid, bvid)) return false;
    if (!await _ensureLoaded()) return false;
    return isFav(aid: aid, bvid: bvid);
  }

  /// 数据已加载时的同步校验（未加载数据时视为不允许，fail-closed）
  static bool isFav({int? aid, String? bvid}) {
    if (!_loaded) return false;
    if (aid != null && _favAids.contains(aid)) return true;
    if (bvid != null && _favBvids.contains(bvid)) return true;
    return false;
  }

  /// 校验入参是否携带视频 id
  static bool _ensureIds(int? aid, String? bvid) {
    if (aid == null && bvid == null) {
      SmartDialog.showToast('无法识别视频 id，已拦截播放');
      return false;
    }
    return true;
  }

  static Future<bool> _ensureLoaded() {
    if (_loaded) return Future.value(true);
    return _loading ??= _loadAll();
  }

  static Future<bool> _loadAll() async {
    SmartDialog.showLoading(msg: '正在获取收藏夹数据');
    try {
      if (!Accounts.main.isLogin) {
        SmartDialog.dismiss(status: SmartStatus.loading);
        SmartDialog.showToast('仅限收藏夹播放需先登录账号');
        return false;
      }

      final foldersRes = await FavHttp.allFavFolders(Accounts.main.mid);
      final folders = switch (foldersRes) {
        Success(:final response) => response.list,
        _ => null,
      };
      if (folders == null) {
        SmartDialog.dismiss(status: SmartStatus.loading);
        SmartDialog.showToast('获取收藏夹列表失败：$foldersRes');
        return false;
      }
      if (folders.isEmpty) {
        SmartDialog.dismiss(status: SmartStatus.loading);
        SmartDialog.showToast('收藏夹为空，开启后无法播放任何视频');
        _loaded = true;
        return true;
      }

      for (final folder in folders) {
        int pn = 1;
        while (true) {
          final res = await FavHttp.userFavFolderDetail(
            mediaId: folder.id,
            pn: pn,
            ps: 20,
          );
          if (res is! Success) {
            SmartDialog.dismiss(status: SmartStatus.loading);
            SmartDialog.showToast('获取收藏内容失败：$res');
            return false;
          }
          final data = res.response;
          for (final media in data.medias ?? const []) {
            // 仅统计视频稿件（type == 2）
            if (media.type == 2) {
              final aid = media.id;
              if (aid != null) _favAids.add(aid);
              final bvid = media.bvid;
              if (bvid != null && bvid.isNotEmpty) _favBvids.add(bvid);
            }
          }
          if (data.hasMore != true) break;
          pn++;
        }
      }

      _loaded = true;
      SmartDialog.dismiss(status: SmartStatus.loading);
      SmartDialog.showToast('收藏夹校验就绪（${_favAids.length} 个视频）');
      return true;
    } catch (e) {
      SmartDialog.dismiss(status: SmartStatus.loading);
      SmartDialog.showToast('获取收藏夹数据异常：$e');
      return false;
    } finally {
      _loading = null;
    }
  }
}

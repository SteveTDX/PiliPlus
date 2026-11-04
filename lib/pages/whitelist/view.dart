import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/sliver_wrap.dart';
import 'package:PiliPlus/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/utils/block_user.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 白名单管理（界面与流程参考屏蔽用户管理）
///
/// 白名单启用后，仅用户名称匹配白名单关键词的视频会显示；
/// 黑名单优先级高于白名单（黑名单命中的视频始终不显示）。
class WhiteListPage extends StatefulWidget {
  const WhiteListPage({super.key});

  @override
  State<WhiteListPage> createState() => _WhiteListPageState();
}

class _WhiteListPageState extends State<WhiteListPage> {
  final Set<String> userNames = GlobalData().whiteUserNames;
  late EdgeInsets padding;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    padding = MediaQuery.viewPaddingOf(context);
  }

  void _persist() {
    Pref.whiteUserNames = userNames;
    // 白名单变更后立即重滤已加载的列表（推荐/热门等），无需手动刷新
    BlockUserFilter.refilterLoadedLists();
  }

  void _onAddUserName(String name) {
    final kw = name.trim();
    if (kw.isEmpty) return;
    if (userNames.contains(kw)) {
      SmartDialog.showToast('该用户名称已存在');
      return;
    }
    userNames.add(kw);
    _persist();
    SmartDialog.showToast('添加成功');
    setState(() {});
  }

  void _showAddUserNameDialog() {
    var text = '';
    showConfirmDialog(
      context: context,
      title: const Text('添加白名单用户'),
      content: TextField(
        autofocus: true,
        textInputAction: .done,
        onChanged: (value) => text = value,
        onSubmitted: (value) {
          Get.back();
          _onAddUserName(value);
        },
        decoration: const InputDecoration(
          labelText: '用户名称关键词',
          hintText: '用户名称包含该关键词的视频才会显示',
          border: OutlineInputBorder(),
        ),
      ),
      onConfirm: () => _onAddUserName(text),
    );
  }

  void _onRemoveUserName(String name) {
    showConfirmDialog(
      context: context,
      title: const Text('确定移除该用户名称？'),
      content: Text(name),
      onConfirm: () {
        userNames.remove(name);
        _persist();
        setState(() {});
      },
    );
  }

  void _showImportExportDialog() {
    showImportExportDialog<List>(
      context,
      title: '白名单',
      localFileName: () => 'whiteUserNames',
      onExport: () => Utils.jsonEncoder.convert(userNames.toList()),
      onImport: (json) {
        for (final item in json) {
          if (item is String && item.trim().isNotEmpty) {
            userNames.add(item.trim());
          }
        }
        _persist();
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(title: const Text('白名单管理')),
      body: ScaffoldLayout(
        fab: Padding(
          padding: .only(
            right: kFloatingActionButtonMargin + padding.right,
            bottom: kFloatingActionButtonMargin + padding.bottom,
          ),
          child: Column(
            spacing: kFloatingActionButtonMargin,
            mainAxisSize: .min,
            children: [
              FloatingActionButton(
                tooltip: '导入/导出',
                onPressed: _showImportExportDialog,
                child: const Icon(Icons.swap_vert, size: 26),
              ),
              FloatingActionButton(
                tooltip: '添加',
                onPressed: _showAddUserNameDialog,
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            ViewSliverSafeArea(
              bottom: 180,
              sliver: userNames.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Text(
                          '白名单为空时不启用白名单过滤\n'
                          '启用后仅用户名称包含白名单关键词的视频会显示\n'
                          '黑名单优先级高于白名单',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const .fromLTRB(12, 12, 12, 0),
                      sliver: SliverFixedWrap(
                        spacing: 8,
                        runSpacing: 8,
                        mainAxisExtent: 30,
                        delegate: SliverChildBuilderDelegate(
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: false,
                          childCount: userNames.length,
                          (context, index) {
                            final name = userNames.elementAt(index);
                            return SearchText(
                              text: name,
                              onLongPress: _onRemoveUserName,
                              onDelete: () {
                                userNames.remove(name);
                                _persist();
                                setState(() {});
                              },
                              height: 1,
                              maxLines: 1,
                              fontSize: 14,
                              overflow: .ellipsis,
                              padding: const .fromLTRB(11, 8, 11, 0),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

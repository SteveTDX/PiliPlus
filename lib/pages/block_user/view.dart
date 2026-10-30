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

/// 屏蔽用户管理（界面与流程参考黑名单管理）
class BlockUserPage extends StatefulWidget {
  const BlockUserPage({super.key});

  @override
  State<BlockUserPage> createState() => _BlockUserPageState();
}

class _BlockUserPageState extends State<BlockUserPage> {
  final Set<String> userNames = GlobalData().blockUserNames;
  late EdgeInsets padding;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    padding = MediaQuery.viewPaddingOf(context);
  }

  void _persist() {
    Pref.blockUserNames = userNames;
    // 关键词变更后立即重滤已加载的列表（推荐/热门等），无需手动刷新
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
    SmartDialog.showToast('屏蔽成功');
    setState(() {});
  }

  void _showAddUserNameDialog() {
    var text = '';
    showConfirmDialog(
      context: context,
      title: const Text('添加屏蔽用户'),
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
          hintText: '用户名称包含该关键词的视频将被屏蔽',
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
      title: '屏蔽用户',
      localFileName: () => 'blockUserNames',
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
      appBar: AppBar(title: const Text('屏蔽用户管理')),
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
                          '暂无屏蔽用户\n用户名称包含任意关键词的视频将不再显示',
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

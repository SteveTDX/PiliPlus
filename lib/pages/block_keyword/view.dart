import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/sliver_wrap.dart';
import 'package:PiliPlus/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 屏蔽关键词管理（界面与流程参考黑名单管理）
class BlockKeywordPage extends StatefulWidget {
  const BlockKeywordPage({super.key});

  @override
  State<BlockKeywordPage> createState() => _BlockKeywordPageState();
}

class _BlockKeywordPageState extends State<BlockKeywordPage> {
  final Set<String> keywords = GlobalData().blockKeywords;
  late EdgeInsets padding;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    padding = MediaQuery.viewPaddingOf(context);
  }

  void _persist() => Pref.blockKeywords = keywords;

  void _onAddKeyword(String keyword) {
    final kw = keyword.trim();
    if (kw.isEmpty) return;
    if (keywords.contains(kw)) {
      SmartDialog.showToast('该关键词已存在');
      return;
    }
    keywords.add(kw);
    _persist();
    SmartDialog.showToast('屏蔽成功');
    setState(() {});
  }

  void _showAddKeywordDialog() {
    var text = '';
    showConfirmDialog(
      context: context,
      title: const Text('添加屏蔽关键词'),
      content: TextField(
        autofocus: true,
        textInputAction: .done,
        onChanged: (value) => text = value,
        onSubmitted: (value) {
          Get.back();
          _onAddKeyword(value);
        },
        decoration: const InputDecoration(
          labelText: '关键词',
          hintText: '标题或标签包含该关键词的视频将被屏蔽',
          border: OutlineInputBorder(),
        ),
      ),
      onConfirm: () => _onAddKeyword(text),
    );
  }

  void _onRemoveKeyword(String keyword) {
    showConfirmDialog(
      context: context,
      title: const Text('确定移除该关键词？'),
      content: Text(keyword),
      onConfirm: () {
        keywords.remove(keyword);
        _persist();
        setState(() {});
      },
    );
  }

  void _showImportExportDialog() {
    showImportExportDialog<List>(
      context,
      title: '屏蔽关键词',
      localFileName: () => 'blockKeywords',
      onExport: () => Utils.jsonEncoder.convert(keywords.toList()),
      onImport: (json) {
        for (final item in json) {
          if (item is String && item.trim().isNotEmpty) {
            keywords.add(item.trim());
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
      appBar: AppBar(title: const Text('屏蔽关键词')),
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
                onPressed: _showAddKeywordDialog,
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
              sliver: keywords.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Text(
                          '暂无屏蔽关键词\n标题或标签包含任意关键词的视频将不再显示',
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
                          childCount: keywords.length,
                          (context, index) {
                            final keyword = keywords.elementAt(index);
                            return SearchText(
                              text: keyword,
                              onLongPress: _onRemoveKeyword,
                              onDelete: () {
                                keywords.remove(keyword);
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

import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/stateful_builder.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/accounts/api_type.dart';
import 'package:PiliPlus/utils/fav_only.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/login_utils.dart';
import 'package:PiliPlus/utils/privacy_password.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide StatefulBuilder;

/// 密码输入框：仅允许数字与英文字母，且不开启联想/自动更正
Widget _passwordField({
  required ValueChanged<String> onChanged,
  String? label,
  bool autofocus = false,
}) {
  return TextField(
    autofocus: autofocus,
    obscureText: true,
    enableSuggestions: false,
    autocorrect: false,
    keyboardType: TextInputType.visiblePassword,
    textInputAction: .done,
    onChanged: onChanged,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
    ],
    decoration: InputDecoration(
      labelText: label ?? '密码',
      border: const OutlineInputBorder(),
    ),
  );
}

/// 进入黑名单管理 / 屏蔽用户管理 / 屏蔽关键词前的密码验证；未设置密码时直接放行
Future<bool> _requirePassword(BuildContext context) async {
  if (!PrivacyPassword.hasPassword) return true;
  if (!context.mounted) return false;

  String password = '';
  return await showDialog<bool>(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('验证密码'),
              content: _passwordField(
                autofocus: true,
                label: '请输入访问密码',
                onChanged: (value) {
                  password = value;
                  setState(() {});
                },
              ),
              actions: [
                TextButton(
                  onPressed: Get.back,
                  child: Text(
                    '取消',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (PrivacyPassword.verify(password)) {
                      Get.back(result: true);
                    } else {
                      SmartDialog.showToast('密码错误');
                    }
                  },
                  child: const Text('确认'),
                ),
              ],
            ),
          );
        },
      ) ??
      false;
}

/// 首次进入密码设置：设置初始密码（两次输入且一致）
void _showInitialPasswordDialog(BuildContext context, VoidCallback setState) {
  final theme = Theme.of(context);
  String password = '';
  String confirm = '';
  final passwordKey = GlobalKey<FormFieldState<String>>();
  final confirmKey = GlobalKey<FormFieldState<String>>();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('设置初始密码'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: .min,
          children: [
            const Text('密码仅允许数字和英文字母（4-32位）'),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, dialogSetState) => Column(
                mainAxisSize: .min,
                children: [
                  TextFormField(
                    key: passwordKey,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    onChanged: (value) {
                      password = value;
                      dialogSetState(() {});
                    },
                    validator: (_) =>
                        password.isEmpty ||
                            !PrivacyPassword.isValid(password)
                        ? '密码需为4-32位数字或英文字母'
                        : null,
                    decoration: const InputDecoration(
                      labelText: '新密码',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: confirmKey,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    onChanged: (value) {
                      confirm = value;
                      dialogSetState(() {});
                    },
                    validator: (_) => confirm != password
                        ? '两次输入的密码不一致'
                        : null,
                    decoration: const InputDecoration(
                      labelText: '确认密码',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: () {
            if (passwordKey.currentState?.validate() != true ||
                confirmKey.currentState?.validate() != true) {
              return;
            }
            PrivacyPassword.setPassword(password);
            Get.back();
            setState();
            SmartDialog.showToast('密码设置成功');
          },
          child: const Text('确认'),
        ),
      ],
    ),
  );
}

/// 已设置密码：先验证当前密码，验证通过后才能进入修改
void _showPasswordChangeFlow(BuildContext context, VoidCallback setState) {
  final theme = Theme.of(context);
  String oldPassword = '';

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, dialogSetState) => AlertDialog(
        title: const Text('验证当前密码'),
        content: _passwordField(
          autofocus: true,
          label: '当前密码',
          onChanged: (value) {
            oldPassword = value;
            dialogSetState(() {});
          },
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              '取消',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              if (PrivacyPassword.verify(oldPassword)) {
                Get.back();
                _showChangePasswordDialog(context, setState);
              } else {
                SmartDialog.showToast('当前密码错误');
              }
            },
            child: const Text('下一步'),
          ),
        ],
      ),
    ),
  );
}

void _showChangePasswordDialog(BuildContext context, VoidCallback setState) {
  final theme = Theme.of(context);
  String password = '';
  String confirm = '';
  final passwordKey = GlobalKey<FormFieldState<String>>();
  final confirmKey = GlobalKey<FormFieldState<String>>();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('修改密码'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: .min,
          children: [
            const Text('修改密码需两次输入且一致；新密码留空并确认则取消密码设置'),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, dialogSetState) => Column(
                mainAxisSize: .min,
                children: [
                  TextFormField(
                    key: passwordKey,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    onChanged: (value) {
                      password = value;
                      dialogSetState(() {});
                    },
                    validator: (_) {
                      if (password.isEmpty && confirm.isEmpty) return null;
                      return PrivacyPassword.isValid(password)
                          ? null
                          : '密码需为4-32位数字或英文字母';
                    },
                    decoration: const InputDecoration(
                      labelText: '新密码（留空则取消密码）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: confirmKey,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    onChanged: (value) {
                      confirm = value;
                      dialogSetState(() {});
                    },
                    validator: (_) {
                      if (password.isEmpty && confirm.isEmpty) return null;
                      return confirm == password ? null : '两次输入的密码不一致';
                    },
                    decoration: const InputDecoration(
                      labelText: '确认新密码（留空则取消密码）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: () {
            if (passwordKey.currentState?.validate() != true ||
                confirmKey.currentState?.validate() != true) {
              return;
            }
            if (password.isEmpty && confirm.isEmpty) {
              PrivacyPassword.clearPassword();
              Get.back();
              setState();
              SmartDialog.showToast('已取消密码设置');
              return;
            }
            PrivacyPassword.setPassword(password);
            Get.back();
            setState();
            SmartDialog.showToast('密码修改成功');
          },
          child: const Text('确认'),
        ),
      ],
    ),
  );
}

void _showPasswordSettingDialog(BuildContext context, VoidCallback setState) {
  if (!PrivacyPassword.hasPassword) {
    _showInitialPasswordDialog(context, setState);
  } else {
    _showPasswordChangeFlow(context, setState);
  }
}

List<SettingsModel> get privacySettings => [
  NormalModel(
    onTap: (context, setState) async {
      if (await _requirePassword(context)) {
        Get.toNamed('/blackListPage');
      }
    },
    title: '黑名单管理',
    subtitle: '已拉黑用户',
    leading: const Icon(Icons.block),
  ),
  NormalModel(
    onTap: (context, setState) async {
      if (await _requirePassword(context)) {
        Get.toNamed('/whiteListPage');
      }
    },
    title: '白名单管理',
    subtitle: '仅显示白名单内用户名称的视频\n优先级低于黑名单',
    leading: const Icon(Icons.verified_user_outlined),
  ),
  SwitchModel(
    title: '仅限收藏夹播放',
    subtitle: '开启后只能播放账号收藏夹内的视频\n首次点击视频时会拉取收藏夹数据',
    setKey: SettingBoxKey.onlyFavPlayback,
    leading: const Icon(Icons.collections_bookmark_outlined),
    onChanged: (value) {
      GlobalData().onlyFavPlayback = value;
      if (value) {
        FavOnlyService.reload();
      } else {
        FavOnlyService.invalidate();
      }
    },
  ),
  NormalModel(
    onTap: (context, setState) async {
      if (await _requirePassword(context)) {
        Get.toNamed('/blockUserPage');
      }
    },
    title: '屏蔽用户管理',
    subtitle: '屏蔽用户名称包含关键词的视频',
    leading: const Icon(Icons.person_off_outlined),
  ),
  NormalModel(
    onTap: (context, setState) async {
      if (await _requirePassword(context)) {
        Get.toNamed('/blockKeywordPage');
      }
    },
    title: '屏蔽关键词',
    subtitle: '屏蔽标题或标签包含关键词的视频',
    leading: const Icon(Icons.filter_alt_off_outlined),
  ),
  NormalModel(
    onTap: _showPasswordSettingDialog,
    getSubtitle: () => PrivacyPassword.hasPassword
        ? '已设置密码，黑名单管理、屏蔽用户与屏蔽关键词需验证密码\n点击修改或取消密码'
        : '未设置密码\n设置后进入黑名单管理、屏蔽用户与屏蔽关键词需验证密码',
    title: '密码设置',
    leading: const Icon(Icons.password_outlined),
  ),
  const NormalModel(
    title: 'buvid设置',
    leading: Icon(CustomIcons.identifier_circle),
    onTap: _showBuvidDialog,
  ),
  NormalModel(
    onTap: (context, setState) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('账号模式详情'),
          content: SelectionArea(
            child: SingleChildScrollView(
              child: _getAccountDetail(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text('确认'),
            ),
          ],
        ),
      );
    },
    leading: const Icon(Icons.flag_outlined),
    title: '了解账号模式',
    subtitle: '查看各个账号模式作用的API列表',
  ),
];

Widget _getAccountDetail(BuildContext context) {
  final children = <Widget>[];
  final theme = TextTheme.of(context);
  for (final i in AccountType.values) {
    final url = ApiType.apiTypeSet[i];
    if (url == null) continue;

    children
      ..add(Center(child: Text(i.title, style: theme.titleMedium)))
      ..add(Text(url.join('\n')));
  }
  return Column(
    spacing: 8,
    mainAxisSize: .min,
    crossAxisAlignment: .start,
    children: children,
  );
}

void _showBuvidDialog(BuildContext context, VoidCallback setState) {
  final filter = [
    FilteringTextInputFormatter.allow(
      RegExp(r"[a-z\d\-_]+", caseSensitive: false),
    ),
  ];
  final controllers = [
    (
      AnonymousAccount(),
      TextEditingController(text: AnonymousAccount().buvid),
    ),
    ...Accounts.account.values.map(
      (i) => (i, TextEditingController(text: i.buvid)),
    ),
  ];
  showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return StatefulBuilder(
        onDispose: () {
          for (var (_, ctr) in controllers) {
            ctr.dispose();
          }
          controllers.clear();
        },
        builder: (context, _) => AlertDialog(
          title: const Text('buvid'),
          content: SingleChildScrollView(
            child: Column(
              spacing: 8,
              mainAxisSize: .min,
              children: controllers
                  .map(
                    (i) => TextField(
                      controller: i.$2,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'mid: ${i.$1.mid}',
                        labelStyle: theme.textTheme.titleMedium,
                        suffixIcon: IconButton(
                          onPressed: () =>
                              i.$2.text = LoginUtils.generateBuvid(),
                          iconSize: 24,
                          tooltip: '随机',
                          icon: const Icon(Icons.casino_outlined),
                        ),
                      ),
                      inputFormatters: filter,
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '取消',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                for (var (account, ctr) in controllers) {
                  if (ctr.text case final text when text.isNotEmpty) {
                    account.buvid = text;
                  }
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    },
  );
}

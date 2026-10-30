import 'dart:convert' show utf8;
import 'dart:math';

import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:crypto/crypto.dart';

/// 隐私设置访问密码
///
/// 密码仅允许数字与英文字母（[isValid] 校验 + 输入框过滤器双重限制），
/// 存储时使用随机盐 + SHA-256 加盐哈希，明文密码不落盘、不参与任何拼接，
/// 防止注入攻击。
abstract final class PrivacyPassword {
  static final RegExp _validPattern = RegExp(r'^[A-Za-z0-9]+$');

  /// 是否已设置密码
  static bool get hasPassword => Pref.privacyPasswordHash.isNotEmpty;

  /// 密码合法性：仅数字与英文字母，长度 4-32
  static bool isValid(String password) =>
      password.length >= 4 &&
      password.length <= 32 &&
      _validPattern.hasMatch(password);

  static String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// 校验密码（未设置密码时返回 false）
  static bool verify(String password) {
    final stored = Pref.privacyPasswordHash;
    if (stored.isEmpty) return false;
    final sep = stored.indexOf(':');
    if (sep <= 0) return false;
    final salt = stored.substring(0, sep);
    final hash = stored.substring(sep + 1);
    return _hash(password, salt) == hash;
  }

  /// 设置（或修改）密码
  static void setPassword(String password) {
    final salt = _randomSalt();
    Pref.privacyPasswordHash = '$salt:${_hash(password, salt)}';
  }

  /// 取消密码设置
  static void clearPassword() => Pref.privacyPasswordHash = '';
}

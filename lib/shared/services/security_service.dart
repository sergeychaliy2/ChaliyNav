import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AES-256-CBC encryption service for sensitive user data.
///
/// The master key is generated on first use.
///
/// Storage: SharedPreferences (base64). This is a compromise — a fully secure
/// enclave would use `flutter_secure_storage` (Android Keystore / iOS
/// Keychain), but that plugin's Gradle artifacts aren't reachable from our
/// current build environment. Phase 5 milestone: swap [`_readKey`] /
/// [`_writeKey`] to the secure-storage impl once the network access is
/// restored. Encrypted *data* itself is unaffected — it's all AES-256 from day
/// one; only the key-at-rest protection changes.
class SecurityService {
  SecurityService._();
  static final SecurityService instance = SecurityService._();

  static const _keyName = 'chaliy_master_key_v1';

  Key? _cachedKey;

  Future<Key> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;
    final stored = await _readKey();
    if (stored != null) {
      _cachedKey = Key.fromBase64(stored);
      return _cachedKey!;
    }
    final rnd = math.Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => rnd.nextInt(256)),
    );
    final key = Key(bytes);
    await _writeKey(key.base64);
    _cachedKey = key;
    return key;
  }

  Future<String?> _readKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  Future<void> _writeKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, value);
  }

  /// Encrypt an arbitrary string. Output = base64(iv + ciphertext).
  Future<String> encryptString(String plain) async {
    final key = await _getKey();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: iv);
    return base64Encode(Uint8List.fromList([...iv.bytes, ...encrypted.bytes]));
  }

  Future<String> decryptString(String b64) async {
    final key = await _getKey();
    final combined = base64Decode(b64);
    final iv = IV(Uint8List.fromList(combined.sublist(0, 16)));
    final cipher = Encrypted(Uint8List.fromList(combined.sublist(16)));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decrypt(cipher, iv: iv);
  }

  /// Encrypt raw bytes — used for backups / photos / audio.
  Future<Uint8List> encryptBytes(List<int> bytes) async {
    final key = await _getKey();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);
    return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
  }

  Future<Uint8List> decryptBytes(List<int> combined) async {
    final key = await _getKey();
    final iv = IV(Uint8List.fromList(combined.sublist(0, 16)));
    final cipher = Encrypted(Uint8List.fromList(combined.sublist(16)));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return Uint8List.fromList(encrypter.decryptBytes(cipher, iv: iv));
  }

  /// Password-based encryption for portable backups.
  /// Layout: salt(16) + iv(16) + ciphertext
  Future<Uint8List> encryptWithPassword(
    List<int> bytes,
    String password,
  ) async {
    final iv = IV.fromSecureRandom(16);
    final salt = IV.fromSecureRandom(16);
    final key = _deriveKey(password, salt.bytes);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);
    return Uint8List.fromList([
      ...salt.bytes,
      ...iv.bytes,
      ...encrypted.bytes,
    ]);
  }

  Future<Uint8List> decryptWithPassword(
    List<int> combined,
    String password,
  ) async {
    if (combined.length < 32) {
      throw const FormatException('Слишком короткий файл бэкапа');
    }
    final salt = Uint8List.fromList(combined.sublist(0, 16));
    final iv = IV(Uint8List.fromList(combined.sublist(16, 32)));
    final cipher = Encrypted(Uint8List.fromList(combined.sublist(32)));
    final key = _deriveKey(password, salt);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    try {
      return Uint8List.fromList(encrypter.decryptBytes(cipher, iv: iv));
    } catch (_) {
      throw const FormatException('Неверный пароль или повреждённый файл');
    }
  }

  Key _deriveKey(String password, List<int> salt) {
    // Lightweight KDF: SHA-256 × 10_000 over password+salt.
    // Upgrade to Argon2 in phase 5.
    var digest = Uint8List.fromList(utf8.encode(password) + salt);
    for (var i = 0; i < 10000; i++) {
      digest = Uint8List.fromList(crypto.sha256.convert(digest).bytes);
    }
    return Key(digest);
  }
}

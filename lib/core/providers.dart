import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jirani_secure_keys/jirani_secure_keys.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/chamas/application/chain_check.dart';
import '../features/chamas/data/chama_repository.dart';
import 'api/api_client.dart';
import 'api/token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: AppConfig.apiBaseUrl, tokens: ref.watch(tokenStoreProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => HttpAuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)),
);

final chamaRepositoryProvider = Provider<ChamaRepository>(
  (ref) => HttpChamaRepository(ref.watch(apiClientProvider)),
);

class PickedFile {
  const PickedFile(this.name, this.bytes);
  final String name;
  final List<int> bytes;
}

/// Picks a statement file. Behind a provider so tests can hand in a file directly.
abstract class FileSource {
  Future<PickedFile?> pickStatement();
  Future<PickedFile?> pickPhoto();
}

class DeviceFileSource implements FileSource {
  @override
  Future<PickedFile?> pickStatement() async {
    final f = await FilePicker.pickFile(type: FileType.custom,
        allowedExtensions: const ['csv', 'pdf']);
    if (f == null) return null;
    return PickedFile(f.name, await f.readAsBytes());
  }

  @override
  Future<PickedFile?> pickPhoto() async {
    final f = await FilePicker.pickFile(type: FileType.image);
    if (f == null) return null;
    return PickedFile(f.name, await f.readAsBytes());
  }
}

final fileSourceProvider = Provider<FileSource>((ref) => DeviceFileSource());

/// Keeps a statement PDF on the phone and hands it to the share sheet (WhatsApp, email,
/// print). Behind a provider so tests do not touch the file system or the share sheet.
abstract class DocumentSaver {
  /// Returns where the file was kept.
  Future<String> save(String filename, List<int> bytes);
  Future<void> share(String path, {required String text});
}

class DeviceDocumentSaver implements DocumentSaver {
  @override
  Future<String> save(String filename, List<int> bytes) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/statements');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<void> share(String path, {required String text}) async {
    await SharePlus.instance.share(ShareParams(
        files: [XFile(path, mimeType: 'application/pdf')], text: text));
  }
}

final documentSaverProvider = Provider<DocumentSaver>((ref) => DeviceDocumentSaver());

/// The phone's signing key (6.7): made once, used after a fingerprint, face or PIN.
/// Remembers which registered device it is, so approvals go to the right key.
abstract class PhoneSigner {
  Future<bool> available();
  Future<String?> deviceId();
  Future<bool> ready();
  Future<CreatedKey> create(List<int> challenge);
  Future<void> remember(String deviceId);
  Future<String> sign(List<int> data, {required String title, required String subtitle});

  /// On sign-out: the key belongs to the person who set it up, not to the next person
  /// who signs in on this phone.
  Future<void> forget();
}

class DevicePhoneSigner implements PhoneSigner {
  DevicePhoneSigner({this.keys = const SecureKeys(),
      this.storage = const FlutterSecureStorage()});

  final SecureKeys keys;
  final FlutterSecureStorage storage;
  static const _idKey = 'signing_device_id';

  @override
  Future<bool> available() => keys.isAvailable();

  @override
  Future<String?> deviceId() => storage.read(key: _idKey);

  @override
  Future<bool> ready() async =>
      await keys.hasKey() && (await deviceId()) != null;

  @override
  Future<CreatedKey> create(List<int> challenge) async {
    await storage.delete(key: _idKey);
    return keys.createKey(challenge);
  }

  @override
  Future<void> remember(String deviceId) => storage.write(key: _idKey, value: deviceId);

  @override
  Future<String> sign(List<int> data, {required String title, required String subtitle}) =>
      keys.sign(data, title: title, subtitle: subtitle);

  @override
  Future<void> forget() async {
    try {
      await storage.delete(key: _idKey);
      await keys.deleteKey();
    } catch (_) {
      // No keystore or secure storage on this platform: nothing to forget.
    }
  }
}

final phoneSignerProvider = Provider<PhoneSigner>((ref) => DevicePhoneSigner());


/// Keeps a screen's data for a while after the screen closes, so going back or switching
/// tabs shows it at once instead of loading it again. Anything that changes the data
/// still refreshes it straight away (ref.invalidate).
extension CacheFor on Ref {
  void cacheFor(Duration duration) {
    // A new sign-in starts with nothing cached from the person before.
    watch(signInEpochProvider);
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}

/// The last record this phone checked in each chama, kept in the phone's secure storage.
class SecureTrustStore implements TrustStore {
  static const _storage = FlutterSecureStorage();

  @override
  Future<TrustedHead?> read(String chamaId) async {
    try {
      final raw = await _storage.read(key: 'chain_head_$chamaId');
      if (raw == null) return null;
      final [seq, hash] = raw.split(':');
      return (seq: int.parse(seq), hash: hash);
    } catch (_) {
      return null; // no trusted head: everything is checked again
    }
  }

  @override
  Future<void> write(String chamaId, TrustedHead head) async {
    try {
      await _storage.write(key: 'chain_head_$chamaId', value: '${head.seq}:${head.hash}');
    } catch (_) {
      // Not kept: the next check simply checks everything again.
    }
  }
}

final trustStoreProvider = Provider<TrustStore>((ref) => SecureTrustStore());


/// Changes at every sign-in and sign-out, which drops every cached screen's data.
class SignInEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final signInEpochProvider = NotifierProvider<SignInEpoch, int>(SignInEpoch.new);

final chainRunnerProvider = Provider<ChainRunner>((ref) => isolateRunner);

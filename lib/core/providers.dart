import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../features/auth/data/auth_repository.dart';
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
}

class DeviceFileSource implements FileSource {
  @override
  Future<PickedFile?> pickStatement() async {
    final f = await FilePicker.pickFile(type: FileType.custom,
        allowedExtensions: const ['csv', 'pdf']);
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

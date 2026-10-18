import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// Compile a version-matched Drift worker and download sqlite3's matching WASM.
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final config =
      jsonDecode(await File('.dart_tool/package_config.json').readAsString())
          as Map;
  final packages = (config['packages'] as List).cast<Map>();
  final sqlite = Directory.fromUri(
    Uri.parse(
      packages.firstWhere((p) => p['name'] == 'sqlite3')['rootUri'] as String,
    ),
  );
  final version =
      RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(await File('${sqlite.path}/pubspec.yaml').readAsString())!
          .group(1)!;
  final target = File('web/sqlite3.wasm');
  final versionFile = File('web/sqlite3.version');
  if (!target.existsSync() ||
      !versionFile.existsSync() ||
      versionFile.readAsStringSync().trim() != version) {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse(
          'https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$version/sqlite3.wasm',
        ),
      );
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('WASM download returned ${response.statusCode}');
      }
      final temporary = File('${target.path}.download');
      await response.pipe(temporary.openWrite());
      await temporary.rename(target.path);
      await versionFile.writeAsString(version);
    } finally {
      client.close();
    }
  }
  final result = await Process.run(Platform.resolvedExecutable, [
    'compile',
    'js',
    '-O2',
    '-o',
    'web/drift_worker.dart.js',
    'web/drift_worker.dart',
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) exit(result.exitCode);
}

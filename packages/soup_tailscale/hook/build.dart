import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const _assetName = 'libtailscale.dart';

Future<void> main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.android) {
      return;
    }

    final sourceDirectory = Directory.fromUri(
      input.packageRoot.resolve('third_party/libtailscale/'),
    );
    if (!sourceDirectory.existsSync()) {
      throw StateError(
        'libtailscale source is missing. Run '
        '`git submodule update --init --recursive` from the Soup repository.',
      );
    }

    final codeConfig = input.config.code;
    final compiler = codeConfig.cCompiler?.compiler;
    if (compiler == null) {
      throw StateError('Flutter did not provide an Android NDK C compiler.');
    }

    final api = codeConfig.android.targetNdkApi;
    final target = _goTarget(codeConfig.targetArchitecture, api);
    final compilerDirectory = File.fromUri(compiler).parent;
    final targetCompiler = File(
      '${compilerDirectory.path}/${target.compilerPrefix}-clang',
    );
    if (!targetCompiler.existsSync()) {
      throw StateError(
        'Android target compiler not found: ${targetCompiler.path}',
      );
    }

    final outputLibrary = File.fromUri(
      input.outputDirectory.resolve('libtailscale.so'),
    );
    await outputLibrary.parent.create(recursive: true);
    final buildSourceDirectory = Directory.fromUri(
      input.outputDirectory.resolve('libtailscale-source/'),
    );
    if (buildSourceDirectory.existsSync()) {
      await buildSourceDirectory.delete(recursive: true);
    }
    await buildSourceDirectory.create(recursive: true);
    for (final name in [
      'go.mod',
      'go.sum',
      'tailscale.go',
      'tailscale.c',
      'tailscale.h',
    ]) {
      await File(
        '${sourceDirectory.path}/$name',
      ).copy('${buildSourceDirectory.path}/$name');
    }
    final androidInterfaces = File.fromUri(
      input.packageRoot.resolve('native/android_interfaces.go'),
    );
    await androidInterfaces.copy(
      '${buildSourceDirectory.path}/android_interfaces.go',
    );

    final environment = <String, String>{
      ...Platform.environment,
      'CGO_ENABLED': '1',
      'GOOS': 'android',
      'GOARCH': target.goArchitecture,
      'CC': targetCompiler.path,
    };
    if (target.goArm case final goArm?) environment['GOARM'] = goArm;
    final result = await Process.run(
      'go',
      [
        'build',
        '-trimpath',
        '-buildvcs=false',
        '-ldflags=-s -w',
        '-buildmode=c-shared',
        '-o',
        outputLibrary.path,
        '.',
      ],
      workingDirectory: buildSourceDirectory.path,
      environment: environment,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'libtailscale Android build failed.\n${result.stdout}\n${result.stderr}',
      );
    }

    final strip = File('${compilerDirectory.path}/llvm-strip');
    if (strip.existsSync()) {
      final stripResult = await Process.run(strip.path, [
        '--strip-unneeded',
        outputLibrary.path,
      ]);
      if (stripResult.exitCode != 0) {
        throw StateError(
          'Failed to strip libtailscale.\n${stripResult.stdout}\n${stripResult.stderr}',
        );
      }
    }

    output.dependencies.addAll(
      sourceDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) => !file.path.contains(
              '${Platform.pathSeparator}.git${Platform.pathSeparator}',
            ),
          )
          .map((file) => file.uri),
    );
    output.dependencies.add(androidInterfaces.uri);
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        linkMode: DynamicLoadingBundled(),
        file: outputLibrary.uri,
      ),
    );
  });
}

({String goArchitecture, String? goArm, String compilerPrefix}) _goTarget(
  Architecture architecture,
  int api,
) {
  if (architecture == Architecture.arm64) {
    return (
      goArchitecture: 'arm64',
      goArm: null,
      compilerPrefix: 'aarch64-linux-android$api',
    );
  }
  if (architecture == Architecture.arm) {
    return (
      goArchitecture: 'arm',
      goArm: '7',
      compilerPrefix: 'armv7a-linux-androideabi$api',
    );
  }
  if (architecture == Architecture.x64) {
    return (
      goArchitecture: 'amd64',
      goArm: null,
      compilerPrefix: 'x86_64-linux-android$api',
    );
  }
  if (architecture == Architecture.ia32) {
    return (
      goArchitecture: '386',
      goArm: null,
      compilerPrefix: 'i686-linux-android$api',
    );
  }
  throw UnsupportedError('Unsupported Android architecture: $architecture');
}

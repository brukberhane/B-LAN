import 'dart:io';

class CommandResult {
  const CommandResult(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get ok => exitCode == 0;
}

abstract class CommandRunner {
  Future<CommandResult> run(String executable, List<String> args);
}

class SystemCommandRunner implements CommandRunner {
  @override
  Future<CommandResult> run(String executable, List<String> args) async {
    try {
      final result = await Process.run(executable, args);
      return CommandResult(
        result.exitCode,
        result.stdout.toString(),
        result.stderr.toString(),
      );
    } on ProcessException {
      return const CommandResult(127, '', '');
    }
  }
}

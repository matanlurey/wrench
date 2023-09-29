import 'dart:convert';
import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  try {
    await _runner.run(args);
  } on UsageException catch (e) {
    io.stdout.writeln(e);
    io.exit(64);
  }
}

final class _GithubCommand extends Command<void> {
  _GithubCommand() {
    addSubcommand(_LoginCommand());
  }

  @override
  String get description => 'Interact with Github';

  @override
  String get name => 'github';
}

final class _LoginCommand extends Command<void> {
  @override
  String get description => 'Login to Github';

  @override
  String get name => 'login';

  /// https://github.com/apps/flutter-engine-wrench-tool
  static const _clientId = 'Iv1.e1692385e0bef549';

  static final _deviceUrl = Uri.parse(
    'https://github.com/login/device/code',
  );

  static final _tokenUrl = Uri.parse(
    'https://github.com/login/oauth/access_token',
  );

  static Future<String?> _requestDeviceCode() async {
    final response = await http.post(
      _deviceUrl,
      body: {
        'client_id': _clientId,
      },
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to request device code: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, Object?>;
    return json['user_code'] as String?;
  }

  static Future<String?> _requestToken(String deviceCode) async {
    final response = await http.post(
      _tokenUrl,
      body: {
        'client_id': _clientId,
        'device_code': deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      },
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to request token: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, Object?>;
    return json['access_token'] as String?;
  }

  @override
  Future<void> run() async {
    final code = await _requestDeviceCode();
    if (code == null) {
      throw Exception('Failed to request device code');
    }

    await _requestToken(code);
    // TODO: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app.
  }
}

final _runner = CommandRunner<void>('wrench', 'Wrench command runner')
  ..addCommand(_GithubCommand());

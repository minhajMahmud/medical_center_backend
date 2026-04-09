import 'dart:io';

import 'package:backend_server/src/birthday_reminder.dart';
import 'package:backend_server/src/web/routes/root.dart';
import 'package:backend_server/src/auth/jwt_authentication_handler.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_shared/serverpod_shared.dart';
import 'src/generated/protocol.dart';
import 'src/generated/endpoints.dart';

String _runModeFromArgs(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];

    if (arg.startsWith('--mode=')) {
      final value = arg.substring('--mode='.length).trim();
      if (value.isNotEmpty) return value;
    }

    if (arg.startsWith('-m=')) {
      final value = arg.substring('-m='.length).trim();
      if (value.isNotEmpty) return value;
    }

    if ((arg == '--mode' || arg == '-m') && i + 1 < args.length) {
      final value = args[i + 1].trim();
      if (value.isNotEmpty) return value;
    }
  }

  final fromEnv = Platform.environment['SERVERPOD_RUN_MODE']?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  return 'development';
}

String? _databasePasswordFromEnvironment() {
  const directPasswordVars = <String>[
    'SERVERPOD_DATABASE_PASSWORD',
    'PGPASSWORD',
    'POSTGRES_PASSWORD',
    'DATABASE_PASSWORD',
    'DB_PASSWORD',
  ];

  for (final name in directPasswordVars) {
    final value = Platform.environment[name]?.trim();
    if (value != null && value.isNotEmpty) return value;
  }

  const databaseUrlVars = <String>[
    'DATABASE_URL',
    'DATABASE_PRIVATE_URL',
    'DATABASE_PUBLIC_URL',
    'POSTGRES_URL',
    'PGURL',
  ];

  for (final name in databaseUrlVars) {
    final url = Platform.environment[name]?.trim();
    if (url == null || url.isEmpty) continue;

    try {
      final uri = Uri.parse(url);
      final userInfo = uri.userInfo;
      if (userInfo.isEmpty) continue;

      final separatorIndex = userInfo.indexOf(':');
      if (separatorIndex == -1 || separatorIndex == userInfo.length - 1) {
        continue;
      }

      final password = Uri.decodeComponent(
        userInfo.substring(separatorIndex + 1),
      );
      if (password.trim().isNotEmpty) return password;
    } catch (_) {
      // Ignore invalid URLs and keep trying the next source.
    }
  }

  return null;
}

ServerpodConfig _loadRailwayAwareConfig(List<String> args) {
  final runMode = _runModeFromArgs(args);
  final passwords = PasswordManager(runMode: runMode).loadPasswords();

  final databasePassword = _databasePasswordFromEnvironment();
  if (databasePassword != null) {
    passwords['database'] = databasePassword;
  }

  return ServerpodConfig.load(runMode, 'default', passwords);
}

void run(List<String> args) async {
  final config = _loadRailwayAwareConfig(args);

  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
    config: config,
    authenticationHandler: jwtAuthenticationHandler,
  );

  // Optional: configure email flows (example prints codes in console)

  pod.webServer.addRoute(RouteRoot(), '/');
  // pod.webServer.addRoute(RouteRoot(), '/index.html');

  await pod.start();

  pod.registerFutureCall(
    BirthdayReminder(),
    FutureCallNames.birthdayReminder.name,
  );
}

enum FutureCallNames { birthdayReminder }

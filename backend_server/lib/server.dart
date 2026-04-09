import 'package:backend_server/src/birthday_reminder.dart';
import 'package:serverpod/serverpod.dart';
import 'package:backend_server/src/web/routes/root.dart';
import 'package:backend_server/src/auth/jwt_authentication_handler.dart';
import 'src/generated/protocol.dart';
import 'src/generated/endpoints.dart';

void run(List<String> args) async {
  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
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

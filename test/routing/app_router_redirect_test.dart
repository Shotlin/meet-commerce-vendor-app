import 'package:flutter_test/flutter_test.dart';

import 'package:freshcuts_vendor_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:freshcuts_vendor_app/routing/app_router.dart';

void main() {
  group('resolveAuthRedirect — the reported "login flash on reopen" bug', () {
    test(
      'a genuinely logged-in vendor never gets sent to /phone while the session is still being restored on cold start',
      () {
        // This is the exact reported bug: on a real cold start, the app
        // starts at AuthStatus.booting for the duration of the real
        // network round trip in AuthNotifier.bootstrap() — the old code
        // unconditionally redirected booting straight to '/phone', so a
        // genuinely-logged-in vendor saw the real login screen for that
        // whole duration before flipping to home. It must go to /splash
        // instead, never /phone, regardless of where the app happened to
        // start.
        expect(resolveAuthRedirect(AuthStatus.booting, '/splash'), isNull);
        expect(resolveAuthRedirect(AuthStatus.booting, '/home'), '/splash');
        expect(resolveAuthRedirect(AuthStatus.booting, '/phone'), '/splash');
        expect(resolveAuthRedirect(AuthStatus.booting, '/requests'), '/splash');
      },
    );

    test('once session restore resolves to authenticated, splash and the login screens both redirect straight to /home', () {
      expect(resolveAuthRedirect(AuthStatus.authenticated, '/splash'), '/home');
      expect(resolveAuthRedirect(AuthStatus.authenticated, '/phone'), '/home');
      expect(resolveAuthRedirect(AuthStatus.authenticated, '/otp/9800000001'), '/home');
    });

    test('an already-authenticated vendor navigating normally is never redirected away from where they are', () {
      expect(resolveAuthRedirect(AuthStatus.authenticated, '/home'), isNull);
      expect(resolveAuthRedirect(AuthStatus.authenticated, '/requests'), isNull);
      expect(resolveAuthRedirect(AuthStatus.authenticated, '/profile'), isNull);
    });

    test('once session restore resolves to unauthenticated or unreachable, splash (and any other route) redirects to /phone', () {
      expect(resolveAuthRedirect(AuthStatus.unauthenticated, '/splash'), '/phone');
      expect(resolveAuthRedirect(AuthStatus.unauthenticated, '/home'), '/phone');
      expect(resolveAuthRedirect(AuthStatus.unreachable, '/splash'), '/phone');
      expect(resolveAuthRedirect(AuthStatus.unreachable, '/requests'), '/phone');
    });

    test('a logged-out vendor is left alone on the phone/OTP screens they are already using', () {
      expect(resolveAuthRedirect(AuthStatus.unauthenticated, '/phone'), isNull);
      expect(resolveAuthRedirect(AuthStatus.unauthenticated, '/otp/9800000001'), isNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/application/session.dart';
import 'features/auth/presentation/code_screen.dart';
import 'features/auth/presentation/phone_screen.dart';
import 'features/auth/presentation/pin_screen.dart';
import 'features/chamas/presentation/chama_screen.dart';
import 'features/chamas/presentation/create_chama_screen.dart';
import 'features/chamas/presentation/join_screen.dart';
import 'features/chamas/presentation/statements_screen.dart';
import 'features/chamas/presentation/unmatched_screen.dart';
import 'features/home/home_screen.dart';

typedef CodeArgs = ({String phone, String hint});

/// Routes follow the session: signed-out members only see sign-in, a member without a
/// PIN is sent to set one, and a signed-in member never sees sign-in again.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<SessionStatus>(ref.read(sessionProvider));
  ref.listen(sessionProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(sessionProvider);
      final path = state.matchedLocation;
      final inSignIn = path.startsWith('/sign-in');
      return switch (status) {
        SessionStatus.unknown => path == '/splash' ? null : '/splash',
        SessionStatus.signedOut => inSignIn ? null : '/sign-in',
        SessionStatus.needsPin => path == '/pin' ? null : '/pin',
        SessionStatus.signedIn => (inSignIn || path == '/pin' || path == '/splash') ? '/' : null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/create', builder: (_, _) => const CreateChamaScreen()),
      GoRoute(path: '/join', builder: (_, _) => const JoinScreen()),
      GoRoute(
        path: '/chamas/:id',
        builder: (_, state) => ChamaScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'statements',
              builder: (_, state) => StatementsScreen(chamaId: state.pathParameters['id']!)),
          GoRoute(path: 'unmatched',
              builder: (_, state) => UnmatchedScreen(chamaId: state.pathParameters['id']!)),
        ],
      ),
      GoRoute(path: '/sign-in', builder: (_, _) => const PhoneScreen(), routes: [
        GoRoute(
          path: 'code',
          builder: (_, state) {
            final args = state.extra as CodeArgs;
            return CodeScreen(phone: args.phone, phoneHint: args.hint);
          },
        ),
      ]),
      GoRoute(path: '/pin', builder: (_, _) => const PinScreen()),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

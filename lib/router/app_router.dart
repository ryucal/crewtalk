import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../providers/app_provider.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/room_list_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier<int>(0);
  ref.listen<UserModel?>(userProvider, (_, __) {
    authRefresh.value++;
  });

  return GoRouter(
    refreshListenable: authRefresh,
    initialLocation: '/login',
    redirect: (context, state) {
      final user = ref.read(userProvider);
      final isLoggedIn = user != null;
      final loc = state.matchedLocation;
      final isLoginRoute = loc == '/login';
      final isSignupRoute = loc == '/signup';

      if (!isLoggedIn && !isLoginRoute && !isSignupRoute) return '/login';
      if (isLoggedIn && (isLoginRoute || isSignupRoute)) return '/rooms';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/rooms',
        builder: (context, state) => const RoomListScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

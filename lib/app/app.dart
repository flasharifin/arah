import 'dart:async';

import 'package:arah/app/di.dart';
import 'package:arah/app/router.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/theme/app_theme.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ArahApp extends StatefulWidget {
  const ArahApp({super.key});

  @override
  State<ArahApp> createState() => _ArahAppState();
}

class _ArahAppState extends State<ArahApp> {
  late final AuthBloc _auth = sl<AuthBloc>()..add(const AuthStarted());
  late final GoRouter _router = createRouter(_auth);
  final _push = sl<PushNotificationService>();
  late final StreamSubscription<String> _routes;

  @override
  void initState() {
    super.initState();
    // Rute dari notifikasi yang di-tap; redirect auth tetap berlaku jika belum login.
    _routes = _push.openedRoutes.listen(_router.go);
  }

  @override
  void dispose() {
    _routes.cancel();
    _router.dispose();
    _auth.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _auth),
        BlocProvider(create: (_) => PrivacyCubit()),
      ],
      // Izin notifikasi diminta setelah login, bukan saat app pertama dibuka.
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (a, b) => a.status != b.status && b.status == AuthStatus.authenticated,
        listener: (_, _) => _push.requestPermissionAndRegister(),
        child: MaterialApp.router(
          title: 'Arah',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: _router,
        ),
      ),
    );
  }
}

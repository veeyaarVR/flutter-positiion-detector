import 'package:flutter_pose/features/home/presentation/pages/home_screen.dart';
import 'package:go_router/go_router.dart';

import '../../features/camera/presentation/pages/camera_screen.dart';
import '../constants/app_route_constants.dart';

class AppRoutes {
  GoRouter router = GoRouter(
    routes: [
      GoRoute(
        name: AppRouteConstants.homepage,
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        name: AppRouteConstants.cameraPage,
        path: '/camera',
        builder: (context, state) => const CameraApp(),
      ),
    ],
  );
}

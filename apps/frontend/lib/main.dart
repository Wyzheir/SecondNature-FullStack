import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // 暂时注释
import 'providers/statistics_provider.dart';

// 导入核心基建
import 'core/database/database_helper.dart';
import 'core/database/goal_dao.dart';
import 'core/database/record_dao.dart';
import 'core/network/dio_client.dart';
import 'core/database/food_dict_dao.dart';

// 导入业务逻辑
import 'repositories/goal_repository_impl.dart';
import 'repositories/sync_service.dart';
import 'providers/goal_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/record_provider.dart';
import 'providers/food_dict_provider.dart';
import 'providers/assistant_provider.dart';

// 导入 UI
import 'ui/screens/auth_wrapper.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===================== 【全局异常拦截配置】 =====================
  
  // 1. 拦截 Flutter 渲染及框架错误（比如 UI 组件报错、Layout 冲突）
  FlutterError.onError = (FlutterErrorDetails details) {
    // 💡 关键修改：注释掉下面这行，阻止它把错误上抛给 VS Code 调试器去截停程序
    // FlutterError.presentError(details); 
    
    // 日志打印到控制台
    debugPrint('\n===================  FLUTTER UI ERROR ===================');
    debugPrint('错误原因: ${details.exception}');
    debugPrint('错误堆栈:\n${details.stack}');
    debugPrint('===========================================================\n');
  };

  // 2. 拦截异步或核心原生错误（比如网络请求未捕获、数据库异步报错、Future.error）
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('\n===================  ASYNC CORE ERROR ===================');
    debugPrint('错误原因: $error');
    debugPrint('错误堆栈:\n$stack');
    debugPrint('===========================================================\n');
    
    // 返回 true 代表告诉系统：这个错误我已经拦截并处理了，别让 App 闪退或卡死
    return true; 
  };




  // 初始化本地数据库与 DAO
  final db = await DatabaseHelper.instance.database;
  final goalDao = GoalDao(db);
  final recordDao = RecordDao(db);
  final foodDictDao = FoodDictDao(db);

  // 实例化全局认证状态
  final authProvider = AuthProvider();

  // 初始化网络层
  final dioClient = DioClient(authProvider);
  final goalRepository = GoalRepositoryImpl(dioClient);

  // 实例化同步服务
  final syncService = SyncService(
    recordDao: recordDao,
    dioClient: dioClient,
    authProvider: authProvider,
  );

  // 启动 App
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        Provider<SyncService>.value(value: syncService),

        ChangeNotifierProvider<StatisticsProvider>(
          create: (_) => StatisticsProvider(dioClient),
        ),

        ChangeNotifierProvider<FoodDictProvider>(
          create: (_) => FoodDictProvider(foodDictDao, dioClient),
        ),

        ChangeNotifierProvider<RecordProvider>(
          create: (context) {
            final rp = RecordProvider(recordDao);
            syncService.onSyncComplete = () {
              final currentUserId = authProvider.userId;
              if (currentUserId != null) {
                Future.delayed(const Duration(milliseconds: 1000), () {
                  rp.loadRecords(currentUserId, isSilent: true);
                });
              }
            };
            return rp;
          },
        ),

        ChangeNotifierProvider<GoalProvider>(
          create: (context) {
            final gp = GoalProvider(
              goalDao: goalDao,
              apiRepository: goalRepository,
            );
            return gp;
          },
        ),
        ChangeNotifierProvider<AssistantProvider>(
          create: (_) => AssistantProvider(dioClient),
        ),
      ],
      child: const HealthApp(),
    ),
  );
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Health Tracker',
      debugShowCheckedModeBanner: false,
      scrollBehavior: MyCustomScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}
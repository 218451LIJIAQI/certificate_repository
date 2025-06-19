import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/logger_service.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/migration_service.dart';
import 'core/services/validation_service.dart';
import 'core/scripts/initialize_admin.dart';
import 'core/services/initialization_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await NotificationService().initialize();
      LoggerService.info('Firebase and notification services initialized successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Firebase initialization error', error: e, stackTrace: stackTrace);
    }
  } else {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      LoggerService.info('Web Firebase initialized successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Web Firebase initialization error', error: e, stackTrace: stackTrace);
    }
  }
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  try {
    final migrationService = MigrationService();
    await migrationService.migrateUserTypes();
    LoggerService.info('✅ User data migration completed successfully');
  } catch (e) {
    LoggerService.warning('⚠️ Migration warning: $e');
  }

  // Initialize system and ensure proper user session management
  try {
    final initializationService = InitializationService();
    
    // Initialize system collections
    await initializationService.initializeSystemCollections();
    LoggerService.info('✅ System collections initialized');
    
    // Comprehensive user validation and initialization
    try {
      final validationResult = await ValidationService.validateUserAuthentication();
      if (validationResult.isValid) {
        LoggerService.info('✅ User authentication validated successfully');
        // Initialize user session with validated user
        await initializationService.initializeUserSession();
      } else if (validationResult.errorMessage != null) {
        LoggerService.warning('⚠️ User validation issue: ${validationResult.errorMessage}');
      }
    } catch (e) {
      LoggerService.warning('⚠️ User validation check failed - continuing with app initialization', error: e);
    }
    
  } catch (e, stackTrace) {
    LoggerService.error('❌ System initialization failed', error: e, stackTrace: stackTrace);
  }
  
  // 🚨 Emergency Fix: Auto-check and create initial Admin account (English comments)
  try {
    LoggerService.info('🔍 Checking for system administrator...');
    final adminStatus = await checkAdminStatusScript();
    
    if (adminStatus['needsInitialization'] == true) {
      LoggerService.info('⚠️ No active admin found - initializing emergency admin account...');
      
      final success = await emergencyAdminFix();
      if (success) {
        LoggerService.info('✅ Emergency admin creation completed - system is now operational!');
      } else {
        LoggerService.error('❌ Failed to create emergency admin - system may require manual setup');
      }
    } else {
      LoggerService.info('✅ System administrator found - admin functionality available');
    }
  } catch (e, stackTrace) {
    LoggerService.error('❌ Admin initialization check failed', error: e, stackTrace: stackTrace);
    LoggerService.info('💡 Manual admin setup available at /admin-setup route');
  }
  
  LoggerService.info('App initialization completed');
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: AppConfig.isDebugMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: themeMode,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}

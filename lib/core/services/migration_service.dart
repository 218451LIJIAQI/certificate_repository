import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import '../models/user_model.dart';

class MigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // Add userType field for existing users
  Future<void> migrateUserTypes() async {
    try {
      _logger.i('Starting userType migration...');
      
      // Get all users without userType field
      final querySnapshot = await _firestore
          .collection('users')
          .get();
      
      int migrated = 0;
      int total = querySnapshot.docs.length;
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Check if userType field already exists
        if (data['userType'] == null) {
          final role = data['role'] as String?;
          UserType userType;
          
          // Map userType based on role
          switch (role) {
            case 'systemAdmin':
              userType = UserType.admin;
              break;
            case 'certificateAuthority':
              userType = UserType.ca;
              break;
            case 'client':
            case 'recipient':
            case 'viewer':
            default:
              userType = UserType.user;
              break;
          }
          
          // Update document
          await doc.reference.update({
            'userType': userType.value,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          migrated++;
          _logger.i('Migrated user ${doc.id}: role=$role -> userType=${userType.value}');
        }
      }
      
      _logger.i('Migration completed: $migrated/$total users migrated');
    } catch (e, stackTrace) {
      _logger.e('Migration failed: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Validate data consistency
  Future<Map<String, dynamic>> validateUserData() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .get();
      
      int totalUsers = querySnapshot.docs.length;
      int validUsers = 0;
      int missingUserType = 0;
      int inconsistentData = 0;
      List<String> issues = [];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final userId = doc.id;
        
        // Check required fields
        if (data['userType'] == null) {
          missingUserType++;
          issues.add('User $userId: missing userType field');
          continue;
        }
        
        // Check data consistency
        final role = data['role'] as String?;
        final userTypeStr = data['userType'] as String?;
        
        if (role != null && userTypeStr != null) {
          final expectedUserType = _getExpectedUserType(role);
          if (expectedUserType.value != userTypeStr) {
            inconsistentData++;
            issues.add('User $userId: role=$role but userType=$userTypeStr (expected ${expectedUserType.value})');
          } else {
            validUsers++;
          }
        }
      }
      
      return {
        'totalUsers': totalUsers,
        'validUsers': validUsers,
        'missingUserType': missingUserType,
        'inconsistentData': inconsistentData,
        'issues': issues,
      };
    } catch (e) {
      _logger.e('Validation failed: $e');
      rethrow;
    }
  }
  
  UserType _getExpectedUserType(String role) {
    switch (role) {
      case 'systemAdmin':
        return UserType.admin;
      case 'certificateAuthority':
        return UserType.ca;
      case 'client':
      case 'recipient':
      case 'viewer':
      default:
        return UserType.user;
    }
  }
} 
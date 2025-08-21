import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/operator_model.dart';
import '../models/technician_model.dart';
import '../models/session_model.dart';
import '../models/machine_model.dart';
import '../models/issue_model.dart';
import '../models/user_model.dart' as app_models;

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Operator operations
  static Future<void> saveOperator(Operator operator) async {
    await _firestore
        .collection('operators')
        .doc(operator.matricule)
        .set(operator.toJson());
  }

  static Future<Operator?> getOperator(String matricule) async {
    final doc = await _firestore.collection('operators').doc(matricule).get();
    if (doc.exists) {
      return Operator.fromJson(doc.data()!);
    }
    return null;
  }

  static Future<void> deleteOperator(String matricule) async {
    await _firestore.collection('operators').doc(matricule).delete();
  }

  static Stream<List<Operator>> getAllOperators() {
    return _firestore
        .collection('operators')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Operator.fromJson(doc.data())).toList());
  }

  // Technician operations
  static Future<void> saveTechnician(Technician technician) async {
    await _firestore
        .collection('technicians')
        .doc(technician.matricule)
        .set(technician.toJson());
  }

  static Future<Technician?> getTechnician(String matricule) async {
    final doc = await _firestore.collection('technicians').doc(matricule).get();
    if (doc.exists) {
      return Technician.fromJson(doc.data()!);
    }
    return null;
  }

  static Future<void> deleteTechnician(String matricule) async {
    await _firestore.collection('technicians').doc(matricule).delete();
  }

  static Stream<List<Technician>> getAllTechnicians() {
    return _firestore
        .collection('technicians')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Technician.fromJson(doc.data())).toList());
  }

  // Session operations
  static Future<void> createSession(Session session) async {
    await _firestore
        .collection('sessions')
        .doc(session.id)
        .set(session.toJson());
  }

  static Future<void> updateSession(Session session) async {
    await _firestore
        .collection('sessions')
        .doc(session.id)
        .update(session.toJson());
  }

  static Stream<List<Session>> getActiveSessions() {
    return _firestore
        .collection('sessions')
        .where('status', whereIn: ['open', 'inProgress'])
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Session.fromJson(doc.data())).toList());
  }

  static Stream<List<Session>> getSessionHistory() {
    return _firestore
        .collection('sessions')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Session.fromJson(doc.data())).toList());
  }

  // Machine operations
  static Future<void> saveMachine(Machine machine) async {
    await _firestore
        .collection('machines')
        .doc(machine.id)
        .set(machine.toJson());
  }

  static Future<Machine?> getMachine(String id) async {
    final doc = await _firestore.collection('machines').doc(id).get();
    if (doc.exists) {
      return Machine.fromJson(doc.data()!);
    }
    return null;
  }

  static Future<void> deleteMachine(String id) async {
    await _firestore.collection('machines').doc(id).delete();
  }

  static Stream<List<Machine>> getMachines() {
    return _firestore
        .collection('machines')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Machine.fromJson(doc.data())).toList());
  }

  static Stream<List<Machine>> getMachinesByAssignedOperator(String operatorId) {
    return _firestore
        .collection('machines')
        .where('assignedOperatorId', isEqualTo: operatorId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Machine.fromJson(doc.data())).toList());
  }

  static Stream<List<Machine>> getMachinesByAssignedOperatorIds(List<String> machineIds) {
    if (machineIds.isEmpty) {
      return Stream.value([]);
    }
    return _firestore
        .collection('machines')
        .where(FieldPath.documentId, whereIn: machineIds)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Machine.fromJson(doc.data())).toList());
  }

  // Chat operations
  static Future<void> sendMessage(String sessionId, String message) async {
    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .update({
          'chatMessages': FieldValue.arrayUnion([message])
        });
  }

  static Stream<List<String>> getMessages(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => List<String>.from(doc.data()?['chatMessages'] ?? []));
  }

  // Work tracking
  static Future<void> startWork(String matricule, String type) async {
    final now = DateTime.now();
    final docRef = _firestore.collection('work_tracking').doc();
    
    await docRef.set({
      'matricule': matricule,
      'type': type,
      'startTime': now.toIso8601String(),
      'endTime': null,
      'status': 'active',
    });
  }

  static Future<void> endWork(String matricule) async {
    final now = DateTime.now();
    final query = await _firestore
        .collection('work_tracking')
        .where('matricule', isEqualTo: matricule)
        .where('status', isEqualTo: 'active')
        .get();

    for (var doc in query.docs) {
      await doc.reference.update({
        'endTime': now.toIso8601String(),
        'status': 'completed',
      });
    }
  }

  static Stream<List<Map<String, dynamic>>> getWorkHistory(String matricule) {
    return _firestore
        .collection('work_tracking')
        .where('matricule', isEqualTo: matricule)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Issue operations
  static Future<void> saveIssue(Issue issue) async {
    await _firestore
        .collection('issues')
        .doc(issue.id)
        .set(issue.toJson());
  }

  static Future<Issue?> getIssue(String id) async {
    final doc = await _firestore.collection('issues').doc(id).get();
    if (doc.exists) {
      return Issue.fromJson(doc.data()!);
    }
    return null;
  }

  static Future<void> deleteIssue(String id) async {
    await _firestore.collection('issues').doc(id).delete();
  }

  static Stream<List<Issue>> getAllIssues() {
    return _firestore
        .collection('issues')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Issue.fromJson(doc.data())).toList());
  }

  static Future<void> updateIssue(Issue issue) async {
    await _firestore
        .collection('issues')
        .doc(issue.id)
        .update(issue.toJson());
  }

  // Admin operations - adminwewire collection (stored by UID)
  static Future<void> saveAdmin(String uid, Map<String, dynamic> adminData) async {
    await _firestore
        .collection('adminwewire')
        .doc(uid)
        .set(adminData);
  }

  static Future<Map<String, dynamic>?> getAdmin(String uid) async {
    final doc = await _firestore.collection('adminwewire').doc(uid).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  static Future<void> deleteAdmin(String uid) async {
    await _firestore.collection('adminwewire').doc(uid).delete();
  }

  static Stream<List<Map<String, dynamic>>> getAllAdmins() {
    return _firestore
        .collection('adminwewire')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Firebase Auth instance
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Admin authentication method using Firebase Authentication
  static Future<app_models.User?> authenticateAdmin(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        // Check if user is an admin in the adminwewire collection
        final adminDoc = await _firestore.collection('adminwewire').doc(userCredential.user!.uid).get();
        
        if (adminDoc.exists) {
          final adminData = adminDoc.data()!;
          return app_models.User(
            id: userCredential.user!.uid,
            name: adminData['name'] ?? 'Admin User',
            email: email,
            role: app_models.UserRole.admin,
            createdAt: DateTime.now(),
          );
        } else {
          // User authenticated but not found in admin collection
          await _auth.signOut();
          return null;
        }
      }
      return null; // Authentication failed
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('Admin authentication error: $e');
      return null;
    }
  }

  // Operator authentication by matricule
  static Future<app_models.User?> authenticateOperator(String matricule) async {
    try {
      final operatorDoc = await _firestore.collection('operators').doc(matricule).get();
      if (operatorDoc.exists) {
        final operatorData = operatorDoc.data()!;
        return app_models.User(
          id: operatorData['matricule'] ?? matricule,
          name: operatorData['name'] ?? 'Operator',
          email: operatorData['email'] ?? '',
          role: app_models.UserRole.operator,
          createdAt: DateTime.now(),
        );
      }
      return null; // Operator not found
    } catch (e) {
      print('Operator authentication error: $e');
      return null;
    }
  }

  // Technician authentication by matricule
  static Future<app_models.User?> authenticateTechnician(String matricule) async {
    try {
      final technicianDoc = await _firestore.collection('technicians').doc(matricule).get();
      if (technicianDoc.exists) {
        final technicianData = technicianDoc.data()!;
        return app_models.User(
          id: technicianData['matricule'] ?? matricule,
          name: technicianData['name'] ?? 'Technician',
          email: technicianData['email'] ?? '',
          role: app_models.UserRole.maintenanceService, // Assuming technicians are maintenance service
          createdAt: DateTime.now(),
        );
      }
      return null; // Technician not found
    } catch (e) {
      print('Technician authentication error: $e');
      return null;
    }
  }

  // Get operator by matricule
  static Future<Operator?> getOperatorByMatricule(String matricule) async {
    try {
      final doc = await _firestore.collection('operators').doc(matricule).get();
      if (doc.exists) {
        return Operator.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting operator: $e');
      return null;
    }
  }

  // Get technician by matricule
  static Future<Technician?> getTechnicianByMatricule(String matricule) async {
    try {
      final doc = await _firestore.collection('technicians').doc(matricule).get();
      if (doc.exists) {
        return Technician.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting technician: $e');
      return null;
    }
  }

  // Check if user exists in any collection
  static Future<bool> userExists(String email) async {
    try {
      // Check operators collection
      final operatorsQuery = await _firestore
          .collection('operators')
          .where('email', isEqualTo: email)
          .get();
      if (operatorsQuery.docs.isNotEmpty) return true;

      // Check technicians collection
      final techniciansQuery = await _firestore
          .collection('technicians')
          .where('email', isEqualTo: email)
          .get();
      if (techniciansQuery.docs.isNotEmpty) return true;

      return false;
    } catch (e) {
      print('User existence check error: $e');
      return false;
    }
  }

  // Check if admin exists by UID
  static Future<bool> adminExists(String uid) async {
    try {
      final adminDoc = await _firestore.collection('adminwewire').doc(uid).get();
      return adminDoc.exists;
    } catch (e) {
      print('Admin existence check error: $e');
      return false;
    }
  }
}

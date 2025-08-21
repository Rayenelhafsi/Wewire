import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/operator_model.dart';
import '../models/technician_model.dart';
import '../models/session_model.dart';
import '../models/machine_model.dart';
import '../models/issue_model.dart';

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
}

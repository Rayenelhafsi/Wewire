import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/operator_model.dart';
import '../models/technician_model.dart';
import '../models/session_model.dart';
import '../models/machine_model.dart';
import '../models/issue_model.dart';
import '../models/user_model.dart' as app_models;
import '../models/private_chat_model.dart';
import '../models/chat_message_model.dart';

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

  // Private Chat operations
  static Future<String> createPrivateChat(String participant1Id, String participant1Name, String participant1Role,
                                         String participant2Id, String participant2Name, String participant2Role) async {
    final chatId = 'private_chat_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    
    final privateChat = PrivateChat(
      id: chatId,
      participant1Id: participant1Id,
      participant2Id: participant2Id,
      participant1Name: participant1Name,
      participant2Name: participant2Name,
      participant1Role: participant1Role,
      participant2Role: participant2Role,
      createdAt: now,
      lastMessageAt: now,
    );

    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .set(privateChat.toJson());

    return chatId;
  }

  static Future<PrivateChat?> getPrivateChat(String chatId) async {
    final doc = await _firestore.collection('private_chats').doc(chatId).get();
    if (doc.exists) {
      return PrivateChat.fromJson(doc.data()!);
    }
    return null;
  }

  static Stream<List<PrivateChat>> getUserPrivateChats(String userId) {
    return _firestore
        .collection('private_chats')
        .where('isActive', isEqualTo: true)
        .where('participant1Id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PrivateChat.fromJson(doc.data()))
            .toList());
  }

  static Future<void> sendPrivateMessage(String chatId, ChatMessage message) async {
    // Save the message
    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toJson());

    // Update the chat with last message info
    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .update({
          'lastMessage': message.toJson(),
          'lastMessageAt': FieldValue.serverTimestamp(),
        });

    // Update unread count for the other participant
    final chatDoc = await _firestore.collection('private_chats').doc(chatId).get();
    if (chatDoc.exists) {
      final chat = PrivateChat.fromJson(chatDoc.data()!);
      final isParticipant1 = chat.participant1Id == message.senderId;
      
      await _firestore
          .collection('private_chats')
          .doc(chatId)
          .update({
            isParticipant1 ? 'unreadCount2' : 'unreadCount1': FieldValue.increment(1),
          });
    }
  }

  static Stream<List<ChatMessage>> getPrivateChatMessages(String chatId) {
    return _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromJson(doc.data()))
            .toList());
  }

  static Future<void> markPrivateMessagesAsRead(String chatId, String userId) async {
    final chatDoc = await _firestore.collection('private_chats').doc(chatId).get();
    if (chatDoc.exists) {
      final chat = PrivateChat.fromJson(chatDoc.data()!);
      final isParticipant1 = chat.participant1Id == userId;
      
      // Reset unread count
      await _firestore
          .collection('private_chats')
          .doc(chatId)
          .update({
            isParticipant1 ? 'unreadCount1' : 'unreadCount2': 0,
          });

      // Mark all messages as read
      final messagesQuery = await _firestore
          .collection('private_chats')
          .doc(chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in messagesQuery.docs) {
        await doc.reference.update({'isRead': true});
      }
    }
  }

  static Future<void> linkChatToIssue(String chatId, String issueId) async {
    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .update({
          'linkedIssueId': issueId,
        });
  }

  static Future<void> closePrivateChat(String chatId) async {
    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .update({
          'isActive': false,
          'closedAt': FieldValue.serverTimestamp(),
        });
  }

  static Future<String?> findExistingPrivateChat(String userId1, String userId2) async {
    final query1 = await _firestore
        .collection('private_chats')
        .where('participant1Id', isEqualTo: userId1)
        .where('participant2Id', isEqualTo: userId2)
        .where('isActive', isEqualTo: true)
        .get();

    if (query1.docs.isNotEmpty) {
      return query1.docs.first.id;
    }

    final query2 = await _firestore
        .collection('private_chats')
        .where('participant1Id', isEqualTo: userId2)
        .where('participant2Id', isEqualTo: userId1)
        .where('isActive', isEqualTo: true)
        .get();

    if (query2.docs.isNotEmpty) {
      return query2.docs.first.id;
    }

    return null;
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

  // Notification operations
  static Future<void> sendNotificationToTechnicians(String title, String body) async {
    try {
      // For web, we can't use subscribeToTopic, so we'll just log the notification
      // For mobile/desktop, we would use topic subscriptions
      print('Notification for technicians: $title - $body');
      
      // Log that technicians would be notified about this issue
      print('Technicians would receive a notification about: $title');
      
    } catch (e) {
      print('Error in notification system: $e');
      // Fallback: just log the notification intent
      print('Notification intent: $title - $body (for technicians)');
    }
  }

  // Issue operations
  static Future<void> saveIssue(Issue issue) async {
    await _firestore
        .collection('issues')
        .doc(issue.id)
        .set(issue.toJson());
    
    // Send notification to technicians about the new issue
    await sendNotificationToTechnicians(
      'New Maintenance Issue',
      'A new issue has been reported: ${issue.description}',
    );
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
    // Include the uid in the admin data to ensure it's available when retrieving
    final dataWithUid = {...adminData, 'uid': uid};
    await _firestore
        .collection('adminwewire')
        .doc(uid)
        .set(dataWithUid);
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
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              // Ensure uid field is present - use document ID if not in data
              if (data != null && !data.containsKey('uid')) {
                return {...data, 'uid': doc.id};
              }
              return data ?? {};
            }).toList());
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

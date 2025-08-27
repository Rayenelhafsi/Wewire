import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
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
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Operator.fromJson(doc.data()))
              .toList(),
        );
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
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Technician.fromJson(doc.data()))
              .toList(),
        );
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
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Session.fromJson(doc.data())).toList(),
        );
  }

  static Stream<List<Session>> getSessionHistory() {
    return _firestore
        .collection('sessions')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Session.fromJson(doc.data())).toList(),
        );
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
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Machine.fromJson(doc.data())).toList(),
        );
  }

  static Stream<List<Machine>> getMachinesByAssignedOperator(
    String operatorId,
  ) {
    return _firestore
        .collection('machines')
        .where('assignedOperatorId', isEqualTo: operatorId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Machine.fromJson(doc.data())).toList(),
        );
  }

  static Stream<List<Machine>> getMachinesByAssignedOperatorIds(
    List<String> machineIds,
  ) {
    if (machineIds.isEmpty) {
      return Stream.value([]);
    }
    return _firestore
        .collection('machines')
        .where(FieldPath.documentId, whereIn: machineIds)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Machine.fromJson(doc.data())).toList(),
        );
  }

  // Chat operations
  static Future<void> sendMessage(String sessionId, String message) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'chatMessages': FieldValue.arrayUnion([message]),
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
  static Future<String> createPrivateChat(
    String participant1Id,
    String participant1Name,
    String participant1Role,
    String participant2Id,
    String participant2Name,
    String participant2Role,
  ) async {
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
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PrivateChat.fromJson(doc.data()))
              .toList(),
        );
  }

  static Future<void> sendPrivateMessage(
    String chatId,
    ChatMessage message,
  ) async {
    // Save the message
    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toJson());

    // Update the chat with last message info
    await _firestore.collection('private_chats').doc(chatId).update({
      'lastMessage': message.toJson(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    // Update unread count for the other participant
    final chatDoc = await _firestore
        .collection('private_chats')
        .doc(chatId)
        .get();
    if (chatDoc.exists) {
      final chat = PrivateChat.fromJson(chatDoc.data()!);
      final isParticipant1 = chat.participant1Id == message.senderId;

      await _firestore.collection('private_chats').doc(chatId).update({
        isParticipant1 ? 'unreadCount2' : 'unreadCount1': FieldValue.increment(
          1,
        ),
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
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromJson(doc.data()))
              .toList(),
        );
  }

  static Future<void> markPrivateMessagesAsRead(
    String chatId,
    String userId,
  ) async {
    final chatDoc = await _firestore
        .collection('private_chats')
        .doc(chatId)
        .get();
    if (chatDoc.exists) {
      final chat = PrivateChat.fromJson(chatDoc.data()!);
      final isParticipant1 = chat.participant1Id == userId;

      // Reset unread count
      await _firestore.collection('private_chats').doc(chatId).update({
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
    await _firestore.collection('private_chats').doc(chatId).update({
      'linkedIssueId': issueId,
    });
  }

  static Future<void> closePrivateChat(String chatId) async {
    await _firestore.collection('private_chats').doc(chatId).update({
      'isActive': false,
      'closedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<String?> findExistingPrivateChat(
    String userId1,
    String userId2,
  ) async {
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
  static Future<void> sendNotificationToTechnicians(
    String title,
    String body, {
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all technicians from Firestore
      final techniciansSnapshot = await _firestore
          .collection('technicians')
          .get();

      final technicians = techniciansSnapshot.docs
          .map((doc) => Technician.fromJson(doc.data()))
          .toList();

      if (technicians.isEmpty) {
        print('No technicians found to notify');
        return;
      }

      print(
        'Sending notification to ${technicians.length} technicians: $title - $body',
      );

      // For each technician, send a notification
      for (final technician in technicians) {
        // Check if the technician has a valid matricule
        if (technician.matricule.isEmpty) {
          print(
            'Warning: Skipping technician with empty matricule: ${technician.name}',
          );
          continue;
        }

        await _sendNotificationToUser(
          technician.matricule,
          title,
          body,
          data: data,
        );
      }
    } catch (e) {
      print('Error sending notifications to technicians: $e');
      // Fallback: log the notification intent
      print('Notification intent: $title - $body (for all technicians)');
    }
  }

  // Send notification to a specific user by matricule
  static Future<void> _sendNotificationToUser(
    String matricule,
    String title,
    String body, {
    Map<String, dynamic>? data,
  }) async {
    try {
      // Look up the user's FCM token from the user_tokens collection
      if (matricule.isEmpty) {
        print('Error: Matricule is empty. Cannot send notification.');
        return;
      }
      print('Retrieving FCM token for user: $matricule');
      final tokenDoc = await _firestore
          .collection('user_tokens')
          .doc(matricule)
          .get();

      if (!tokenDoc.exists) {
        print(
          'No FCM token found for user $matricule. Cannot send notification.',
        );
        return;
      }

      final tokenData = tokenDoc.data();
      final fcmToken = tokenData?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        print(
          'Invalid FCM token for user $matricule. Cannot send notification.',
        );
        return;
      }

      // Send the notification via FCM
      print('Sending FCM notification to user $matricule: $title - $body');

      // Authenticate using the service account JSON file
      final serviceAccountFile = File(
        'C:/Users/elhaf/OneDrive/Desktop/Wewire/Wewire/wewire-18bc2-firebase-adminsdk-fbsvc-002ee0451c.json',
      );
      final serviceAccountContent = await serviceAccountFile.readAsString();
      final serviceAccountJson = jsonDecode(serviceAccountContent);

      final authClient = await clientViaServiceAccount(
        ServiceAccountCredentials.fromJson(serviceAccountJson),
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );
      final accessToken = await authClient.credentials.accessToken;
      final projectId = serviceAccountJson['project_id'] ?? 'wewire-18bc2';

      // Send the notification via FCM HTTP v1 API
      final fcmResponse = await http.post(
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {'title': title, 'body': body, 'sound': 'default'},
            'data': data ?? {},
          },
        }),
      );

      if (fcmResponse.statusCode == 200) {
        print('FCM notification sent successfully to $matricule');
        print('Response: ${fcmResponse.body}');
      } else {
        print(
          'Failed to send FCM notification: ${fcmResponse.statusCode} - ${fcmResponse.body}',
        );
      }
    } catch (e) {
      print('Error sending notification to user $matricule: $e');
    }
  }

  // Store FCM token for a user (to be called when user logs in)
  static Future<void> storeFCMToken(String matricule, String fcmToken) async {
    try {
      // Validate inputs to prevent null values being sent to Firestore
      if (matricule.isEmpty || fcmToken.isEmpty) {
        print(
          'Warning: Attempted to store FCM token with empty matricule or token. Matricule: "$matricule", Token: "$fcmToken"',
        );
        return;
      }

      if (matricule == 'null' || fcmToken == 'null') {
        print(
          'Warning: Attempted to store FCM token with "null" string values. Matricule: "$matricule", Token: "$fcmToken"',
        );
        return;
      }

      await _firestore.collection('user_tokens').doc(matricule).set({
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('FCM token stored for user $matricule');
    } catch (e) {
      print('Error storing FCM token for user $matricule: $e');
      // Re-throw the error to provide better debugging context
      throw Exception('Failed to store FCM token for user $matricule: $e');
    }
  }

  // Remove FCM token when user logs out
  static Future<void> removeFCMToken(String matricule) async {
    try {
      await _firestore.collection('user_tokens').doc(matricule).delete();
      print('FCM token removed for user $matricule');
    } catch (e) {
      print('Error removing FCM token for user $matricule: $e');
    }
  }

  // Issue operations
  static Future<void> saveIssue(Issue issue) async {
    await _firestore.collection('issues').doc(issue.id).set(issue.toJson());

    // Retrieve all technician tokens from Firestore
    final techniciansSnapshot = await _firestore
        .collection('user_tokens')
        .get();
    final technicianTokens = techniciansSnapshot.docs
        .map((doc) => doc.data()['fcmToken'] as String)
        .toList();

    for (final token in technicianTokens) {
      final response = await http.post(
        Uri.parse('http://localhost:3000/sendNotification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'title': 'New Maintenance Issue',
          'body': 'A new issue has been reported: ${issue.description}',
        }),
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully to $token');
      } else {
        print('Failed to send notification: ${response.body}');
      }
    }
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
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Issue.fromJson(doc.data())).toList(),
        );
  }

  static Future<void> updateIssue(Issue issue) async {
    await _firestore.collection('issues').doc(issue.id).update(issue.toJson());
  }

  // Admin operations - adminwewire collection (stored by UID)
  static Future<void> saveAdmin(
    String uid,
    Map<String, dynamic> adminData,
  ) async {
    // Include the uid in the admin data to ensure it's available when retrieving
    final dataWithUid = {...adminData, 'uid': uid};
    await _firestore.collection('adminwewire').doc(uid).set(dataWithUid);
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
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            // Ensure uid field is present - use document ID if not in data
            if (data != null && !data.containsKey('uid')) {
              return {...data, 'uid': doc.id};
            }
            return data ?? {};
          }).toList(),
        );
  }

  // Firebase Auth instance
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Admin authentication method using Firebase Authentication
  static Future<app_models.User?> authenticateAdmin(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Check if user is an admin in the adminwewire collection
        final adminDoc = await _firestore
            .collection('adminwewire')
            .doc(userCredential.user!.uid)
            .get();

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
      final operatorDoc = await _firestore
          .collection('operators')
          .doc(matricule)
          .get();
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
  static Future<app_models.User?> authenticateTechnician(
    String matricule,
  ) async {
    try {
      final technicianDoc = await _firestore
          .collection('technicians')
          .doc(matricule)
          .get();
      if (technicianDoc.exists) {
        final technicianData = technicianDoc.data()!;
        return app_models.User(
          id: technicianData['matricule'] ?? matricule,
          name: technicianData['name'] ?? 'Technician',
          email: technicianData['email'] ?? '',
          role: app_models
              .UserRole
              .maintenanceService, // Assuming technicians are maintenance service
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
      final doc = await _firestore
          .collection('technicians')
          .doc(matricule)
          .get();
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
      final adminDoc = await _firestore
          .collection('adminwewire')
          .doc(uid)
          .get();
      return adminDoc.exists;
    } catch (e) {
      print('Admin existence check error: $e');
      return false;
    }
  }

  // Get current authenticated user
  static app_models.User? getCurrentUser() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      // Return a basic user object with the current Firebase Auth user info
      return app_models.User(
        id: currentUser.uid,
        name: currentUser.displayName ?? 'User',
        email: currentUser.email ?? '',
        role: app_models
            .UserRole
            .admin, // Default to admin for Firebase Auth users
        createdAt: DateTime.now(),
      );
    }
    return null;
  }
}

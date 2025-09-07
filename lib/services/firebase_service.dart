library firebase_service;

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:logging/logging.dart';
import '../models/operator_model.dart';
import '../models/technician_model.dart';
import '../models/session_model.dart';
import '../models/machine_model.dart';
import '../models/issue_model.dart';
import '../models/user_model.dart' as app_models;
import '../models/private_chat_model.dart';
import '../models/chat_message_model.dart';
import '../models/machine_analytics_model.dart';

/// Global flag to control analytics updates
bool analyticsUpdatesEnabled = true;

class FirebaseService {
  static final Logger _logger = Logger('FirebaseService');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseDatabase _realtimeDatabase =
      FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://wewire-18bc2-default-rtdb.firebaseio.com/',
      );

  // Operator operations
  static Future<void> saveOperator(Operator operator) async {
    await _firestore
        .collection('operators')
        .doc(operator.matricule)
        .set(operator.toJson());
  }

  /// Listen for RFID tag UID scans for a given machine in Realtime Database "scans/{machineId}" path.
  /// Returns a stream of tag UIDs detected for the machine.
  static Stream<String> listenForRfidTagScans(String machineId) {
    final DatabaseReference scansRef = _realtimeDatabase.ref(
      'scans/$machineId',
    );

    print(
      'listenForRfidTagScans: Listener attached to /scans/$machineId',
    ); // Debug print

    // Listen to child added events under "scans/{machineId}"
    return scansRef.onChildAdded
        .asyncMap((event) async {
          print(
            'listenForRfidTagScans: onChildAdded event received',
          ); // Debug print
          print(
            'listenForRfidTagScans: Event data: ${event.snapshot.value}',
          ); // Debug print
          final data = event.snapshot.value;
          if (data is Map<dynamic, dynamic>) {
            final uid = data['uid'] as String?;
            if (uid != null) {
              print('listenForRfidTagScans: Emitting uid: $uid'); // Debug print
              return uid;
            } else {
              print(
                'listenForRfidTagScans: No uid field found in data',
              ); // Debug print
            }
          } else {
            print(
              'listenForRfidTagScans: Data is not a Map: $data',
            ); // Debug print
          }
          return null;
        })
        .where((uid) => uid != null)
        .cast<String>();
  }

  /// Manual fetch of current scans data for testing read access and data structure.
  static Future<List<String>> fetchCurrentScans() async {
    final DatabaseReference scansRef = _realtimeDatabase.ref('scans');
    try {
      final snapshot = await scansRef.get();
      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map<dynamic, dynamic>) {
          final uids = data.values
              .map((entry) => entry['uid'] as String?)
              .whereType<String>()
              .toList();
          print('fetchCurrentScans: Retrieved UIDs: $uids');
          return uids;
        } else {
          print('fetchCurrentScans: Data is not a Map: $data');
        }
      } else {
        print('fetchCurrentScans: No data found at /scans');
      }
    } catch (e) {
      print('fetchCurrentScans: Error fetching scans: $e');
    }
    return [];
  }

  /// Fetch the last scanned UID for a specific machine from Realtime Database "scans/{machineId}" path.
  static Future<String?> fetchLastScanForMachine(String machineId) async {
    final DatabaseReference scansRef = _realtimeDatabase.ref(
      'scans/$machineId',
    );
    try {
      final snapshot = await scansRef.orderByKey().limitToLast(1).get();
      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map<dynamic, dynamic>) {
          // The last scan entry is the only entry in this map
          final lastEntry = data.values.first;
          if (lastEntry is Map<dynamic, dynamic>) {
            final uid = lastEntry['uid'] as String?;
            if (uid != null) {
              print('fetchLastScanForMachine: Retrieved last UID: $uid');
              return uid;
            }
          }
        } else {
          print('fetchLastScanForMachine: Data is not a Map: $data');
        }
      } else {
        print('fetchLastScanForMachine: No data found at /scans/$machineId');
      }
    } catch (e) {
      print('fetchLastScanForMachine: Error fetching last scan: $e');
    }
    return null;
  }

  /// Update the operator Firestore document with the RFID tag UID if not already set.
  static Future<void> updateOperatorRfidTagIfMissing(
    String operatorMatricule,
    String rfidTagUid,
  ) async {
    final docRef = _firestore.collection('operators').doc(operatorMatricule);
    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      if (data != null &&
          (data['rfidTagUid'] == null || data['rfidTagUid'] == '')) {
        await docRef.update({'rfidTagUid': rfidTagUid});
      }
    }
  }

  /// Check if an RFID tag UID is already owned by another operator
  static Future<String?> getOperatorByRfidTag(String rfidTagUid) async {
    try {
      final query = await _firestore
          .collection('operators')
          .where('rfidTagUid', isEqualTo: rfidTagUid)
          .get();

      if (query.docs.isNotEmpty) {
        final operatorData = query.docs.first.data();
        return operatorData['matricule'] as String?;
      }
      return null; // Tag not owned by any operator
    } catch (e) {
      print('Error checking RFID tag ownership: $e');
      return null;
    }
  }

  /// Assign RFID tag to operator if not already owned
  static Future<bool> assignRfidTagToOperator(
    String operatorMatricule,
    String rfidTagUid,
  ) async {
    try {
      // First check if tag is already owned by another operator
      final existingOwner = await getOperatorByRfidTag(rfidTagUid);
      if (existingOwner != null && existingOwner != operatorMatricule) {
        print(
          'RFID tag $rfidTagUid is already owned by operator $existingOwner',
        );
        return false; // Tag already owned by another operator
      }

      // Check if operator already has a tag assigned
      final operatorDoc = await _firestore
          .collection('operators')
          .doc(operatorMatricule)
          .get();

      if (operatorDoc.exists) {
        final operatorData = operatorDoc.data();
        final existingTag = operatorData?['rfidTagUid'] as String?;

        if (existingTag != null && existingTag.isNotEmpty) {
          print(
            'Operator $operatorMatricule already has RFID tag $existingTag assigned',
          );
          return existingTag ==
              rfidTagUid; // Return true only if it's the same tag
        }
      }

      // Assign the tag to the operator
      await _firestore.collection('operators').doc(operatorMatricule).update({
        'rfidTagUid': rfidTagUid,
        'rfidTagAssignedAt': FieldValue.serverTimestamp(),
      });

      print(
        'Successfully assigned RFID tag $rfidTagUid to operator $operatorMatricule',
      );
      return true;
    } catch (e) {
      print('Error assigning RFID tag to operator: $e');
      return false;
    }
  }

  /// Verify if the scanned RFID tag belongs to the current operator
  static Future<bool> verifyOperatorRfidTag(
    String operatorMatricule,
    String scannedRfidTagUid,
  ) async {
    try {
      final operatorDoc = await _firestore
          .collection('operators')
          .doc(operatorMatricule)
          .get();

      if (operatorDoc.exists) {
        final operatorData = operatorDoc.data();
        final assignedTag = operatorData?['rfidTagUid'] as String?;
        return assignedTag == scannedRfidTagUid;
      }
      return false;
    } catch (e) {
      print('Error verifying operator RFID tag: $e');
      return false;
    }
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

  static Future<Session?> getSessionById(String sessionId) async {
    final doc = await _firestore.collection('sessions').doc(sessionId).get();
    if (doc.exists) {
      return Session.fromJson(doc.data()!);
    }
    return null;
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

  static Future<List<Session>> getActiveSessionsByOperator(
    String operatorMatricule,
  ) async {
    final query = await _firestore
        .collection('sessions')
        .where('operatorMatricule', isEqualTo: operatorMatricule)
        .where('status', whereIn: ['open', 'inProgress'])
        .get();

    return query.docs.map((doc) => Session.fromJson(doc.data())).toList();
  }

  static Future<List<Session>> getActiveSessionsByMachine(
    String machineId,
  ) async {
    final query = await _firestore
        .collection('sessions')
        .where('machineReference', isEqualTo: machineId)
        .where('status', whereIn: ['open', 'inProgress'])
        .get();

    return query.docs.map((doc) => Session.fromJson(doc.data())).toList();
  }

  /// Closes all active sessions (status open or inProgress) for the given operator matricule
  static Future<void> closeActiveSessionsForOperator(
    String operatorMatricule,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('sessions')
          .where('operatorMatricule', isEqualTo: operatorMatricule)
          .where('status', whereIn: ['open', 'inProgress'])
          .get();

      final batch = _firestore.batch();
      final now = DateTime.now();

      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'status': 'closed',
          'endTime': now.toIso8601String(),
        });
      }

      await batch.commit();
    } catch (e) {
      print(
        'Error closing active sessions for operator $operatorMatricule: $e',
      );
      rethrow;
    }
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
      lastMessageAt: Timestamp.fromDate(now),
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
    // Since Firestore doesn't support OR queries natively, we'll need to combine two streams
    // This is a simplified version that only checks participant1Id
    // In a production app, you'd want to implement a more robust solution
    return _firestore
        .collection('private_chats')
        .where('isActive', isEqualTo: true)
        .where('participant1Id', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          final chats = snapshot.docs
              .map((doc) => PrivateChat.fromJson(doc.data()))
              .toList();
          final participant2Chats = await _firestore
              .collection('private_chats')
              .where('isActive', isEqualTo: true)
              .where('participant2Id', isEqualTo: userId)
              .get();
          chats.addAll(
            participant2Chats.docs
                .map((doc) => PrivateChat.fromJson(doc.data()))
                .toList(),
          );
          return chats;
        });
  }

  // Alternative method to get all chats for a user (both as participant1 and participant2)
  static Stream<List<PrivateChat>> getAllUserPrivateChats(String userId) {
    // This would require a more complex implementation with multiple queries
    // For now, we'll use the existing method
    return getUserPrivateChats(userId);
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
            'notification': {
              'title': title ?? 'Notification',
              'body': body ?? 'You have a new notification',
              'sound': 'default',
            },
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

  // Public method to send notification to a specific operator
  static Future<void> sendNotificationToOperator(
    String operatorMatricule,
    String title,
    String body, {
    Map<String, dynamic>? data,
  }) async {
    await _sendNotificationToUser(operatorMatricule, title, body, data: data);
  }

  // Store FCM token for a user (to be called when user logs in)
  static Future<void> storeFCMToken(String? matricule, String? fcmToken) async {
    try {
      // Validate inputs to prevent null values being sent to Firestore
      if (matricule == null || fcmToken == null) {
        print(
          'Warning: Attempted to store FCM token with null matricule or token. Matricule: "$matricule", Token: "$fcmToken"',
        );
        return;
      }

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
      // Don't re-throw the error to prevent app crashes during initialization
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

  // Session operations
  static Future<void> deleteSession(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).delete();
  }

  // Issue operations
  static Future<void> saveIssue(Issue issue) async {
    await _firestore.collection('issues').doc(issue.id).set(issue.toJson());

    // Retrieve all technician tokens from Firestore
    final techniciansSnapshot = await _firestore
        .collection('user_tokens')
        .get();
    final technicianTokens = techniciansSnapshot.docs
        .map((doc) => doc.data()?['fcmToken'] as String?)
        .where((token) => token != null && token.isNotEmpty)
        .cast<String>()
        .toList();

    if (technicianTokens.isEmpty) {
      print('No valid FCM tokens found for technicians');
      return;
    }

    for (final token in technicianTokens) {
      try {
        final response = await http.post(
          Uri.parse('https://wewire.vercel.app/api/sendNotification'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': token,
            'title': 'New Maintenance Issue',
            'body':
                'A new issue has been reported: ${issue.description ?? 'No description provided'}',
          }),
        );

        if (response.statusCode == 200) {
          print('Notification sent successfully to $token');
        } else {
          print('Failed to send notification: ${response.body}');
        }
      } catch (e) {
        print('Error sending notification to token $token: $e');
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

  // Machine Analytics operations
  static Future<void> saveMachineAnalytics(MachineAnalytics analytics) async {
    print('saveMachineAnalytics called for machineId: ${analytics.machineId}');
    print('Data to save: ${analytics.toJson()}');
    await _firestore
        .collection('machines')
        .doc(analytics.machineId)
        .collection('analytics')
        .doc('overview')
        .set(analytics.toJson());
  }

  static Future<MachineAnalytics?> getMachineAnalytics(String machineId) async {
    final doc = await _firestore
        .collection('machines')
        .doc(machineId)
        .collection('analytics')
        .doc('overview')
        .get();

    if (doc.exists) {
      return MachineAnalytics.fromJson(doc.data()!);
    }
    return null;
  }

  static Stream<MachineAnalytics?> streamMachineAnalytics(String machineId) {
    return _firestore
        .collection('machines')
        .doc(machineId)
        .collection('analytics')
        .doc('overview')
        .snapshots()
        .map(
          (doc) => doc.exists ? MachineAnalytics.fromJson(doc.data()!) : null,
        );
  }

  /// Initialize default analytics document for a machine if it does not exist
  static Future<void> initializeMachineAnalyticsIfMissing(
    String machineId,
  ) async {
    final docRef = _firestore
        .collection('machines')
        .doc(machineId)
        .collection('analytics')
        .doc('overview');

    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) {
      final now = DateTime.now();
      final defaultAnalytics = MachineAnalytics(
        machineId: machineId,
        dailyStoppedTime: {},
        monthlyStoppedTime: {},
        yearlyStoppedTime: {},
        totalWorkingTime: Duration.zero,
        totalStoppedTime: Duration.zero,
        stoppedWithoutMaintenanceTime: Duration.zero,
        stoppedReadyForWorkTime: Duration.zero,
        maintenanceInProgressTime: Duration.zero,
        lastUpdated: now,
      );
      await docRef.set(defaultAnalytics.toJson());
      print('Initialized default analytics for machine $machineId');
    }
  }

  static Future<void> updateMachineAnalytics(
    String machineId,
    Map<String, dynamic> updates,
  ) async {
    if (!analyticsUpdatesEnabled) {
      print(
        'Analytics update skipped for machineId: $machineId because updates are disabled',
      );
      return;
    }
    try {
      print(
        'updateMachineAnalytics called for machineId: $machineId with updates: $updates',
      );
      await _firestore
          .collection('machines')
          .doc(machineId)
          .collection('analytics')
          .doc('overview')
          .set(updates, SetOptions(merge: true));
      print('updateMachineAnalytics succeeded for machineId: $machineId');
    } catch (e) {
      print('Error in updateMachineAnalytics for machineId: $machineId - $e');
      rethrow;
    }
  }

  static Future<void> updateDailyStoppedTime(
    String machineId,
    Duration additionalTime,
  ) async {
    final now = DateTime.now();
    print(
      'updateDailyStoppedTime called for machineId: $machineId with additionalTime: $additionalTime',
    );
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final analytics =
        await getMachineAnalytics(machineId) ??
        MachineAnalytics(
          machineId: machineId,
          dailyStoppedTime: {},
          monthlyStoppedTime: {},
          yearlyStoppedTime: {},
          totalWorkingTime: Duration.zero,
          totalStoppedTime: Duration.zero,
          stoppedWithoutMaintenanceTime: Duration.zero,
          stoppedReadyForWorkTime: Duration.zero,
          maintenanceInProgressTime: Duration.zero,
          lastUpdated: now,
        );

    final currentDailyTime =
        analytics.dailyStoppedTime[dateKey] ?? Duration.zero;
    final newDailyTime = currentDailyTime + additionalTime;

    // Create the full dailyStoppedTime map with the updated value
    final updatedDailyStoppedTime = {...analytics.dailyStoppedTime};
    updatedDailyStoppedTime[dateKey] = newDailyTime;

    await updateMachineAnalytics(machineId, {
      'dailyStoppedTime': MachineAnalytics.durationMapToJson(
        updatedDailyStoppedTime,
      ),
      'totalStoppedTime':
          analytics.totalStoppedTime.inSeconds + additionalTime.inSeconds,
      'lastUpdated': now.toIso8601String(),
    });
  }

  static Future<void> updateWorkingTime(
    String machineId,
    Duration additionalTime,
  ) async {
    final now = DateTime.now();
    print(
      'updateWorkingTime called for machineId: $machineId with additionalTime: $additionalTime',
    );
    final analytics =
        await getMachineAnalytics(machineId) ??
        MachineAnalytics(
          machineId: machineId,
          dailyStoppedTime: {},
          monthlyStoppedTime: {},
          yearlyStoppedTime: {},
          totalWorkingTime: Duration.zero,
          totalStoppedTime: Duration.zero,
          stoppedWithoutMaintenanceTime: Duration.zero,
          stoppedReadyForWorkTime: Duration.zero,
          maintenanceInProgressTime: Duration.zero,
          lastUpdated: now,
        );

    await updateMachineAnalytics(machineId, {
      'totalWorkingTime':
          analytics.totalWorkingTime.inSeconds + additionalTime.inSeconds,
      'lastUpdated': now.toIso8601String(),
    });
  }

  static Future<void> updateMaintenanceInProgressTime(
    String machineId,
    Duration additionalTime,
  ) async {
    final now = DateTime.now();
    final analytics =
        await getMachineAnalytics(machineId) ??
        MachineAnalytics(
          machineId: machineId,
          dailyStoppedTime: {},
          monthlyStoppedTime: {},
          yearlyStoppedTime: {},
          totalWorkingTime: Duration.zero,
          totalStoppedTime: Duration.zero,
          stoppedWithoutMaintenanceTime: Duration.zero,
          stoppedReadyForWorkTime: Duration.zero,
          maintenanceInProgressTime: Duration.zero,
          lastUpdated: now,
        );

    await updateMachineAnalytics(machineId, {
      'maintenanceInProgressTime':
          analytics.maintenanceInProgressTime.inSeconds +
          additionalTime.inSeconds,
      'lastUpdated': now.toIso8601String(),
    });

    // Recalculate totalStoppedTime
    final totalStoppedTime =
        analytics.maintenanceInProgressTime +
        analytics.stoppedWithoutMaintenanceTime +
        analytics.stoppedReadyForWorkTime +
        additionalTime;

    await updateMachineAnalytics(machineId, {
      'totalStoppedTime': totalStoppedTime.inSeconds,
      'lastUpdated': now.toIso8601String(),
    });
  }

  static Future<void> updateStoppedWithoutMaintenanceTime(
    String machineId,
    Duration additionalTime,
  ) async {
    final now = DateTime.now();
    final analytics =
        await getMachineAnalytics(machineId) ??
        MachineAnalytics(
          machineId: machineId,
          dailyStoppedTime: {},
          monthlyStoppedTime: {},
          yearlyStoppedTime: {},
          totalWorkingTime: Duration.zero,
          totalStoppedTime: Duration.zero,
          stoppedWithoutMaintenanceTime: Duration.zero,
          stoppedReadyForWorkTime: Duration.zero,
          maintenanceInProgressTime: Duration.zero,
          lastUpdated: now,
        );

    await updateMachineAnalytics(machineId, {
      'stoppedWithoutMaintenanceTime':
          analytics.stoppedWithoutMaintenanceTime.inSeconds +
          additionalTime.inSeconds,
      'lastUpdated': now.toIso8601String(),
    });

    // Recalculate totalStoppedTime
    final totalStoppedTime =
        analytics.maintenanceInProgressTime +
        analytics.stoppedWithoutMaintenanceTime +
        analytics.stoppedReadyForWorkTime +
        additionalTime;

    await updateMachineAnalytics(machineId, {
      'totalStoppedTime': totalStoppedTime.inSeconds,
      'lastUpdated': now.toIso8601String(),
    });
  }

  static Future<void> updateStoppedReadyForWorkTime(
    String machineId,
    Duration additionalTime,
  ) async {
    final now = DateTime.now();
    final analytics =
        await getMachineAnalytics(machineId) ??
        MachineAnalytics(
          machineId: machineId,
          dailyStoppedTime: {},
          monthlyStoppedTime: {},
          yearlyStoppedTime: {},
          totalWorkingTime: Duration.zero,
          totalStoppedTime: Duration.zero,
          stoppedWithoutMaintenanceTime: Duration.zero,
          stoppedReadyForWorkTime: Duration.zero,
          maintenanceInProgressTime: Duration.zero,
          lastUpdated: now,
        );

    await updateMachineAnalytics(machineId, {
      'stoppedReadyForWorkTime':
          analytics.stoppedReadyForWorkTime.inSeconds +
          additionalTime.inSeconds,
      'lastUpdated': now.toIso8601String(),
    });

    // Recalculate totalStoppedTime
    final totalStoppedTime =
        analytics.maintenanceInProgressTime +
        analytics.stoppedWithoutMaintenanceTime +
        analytics.stoppedReadyForWorkTime +
        additionalTime;

    await updateMachineAnalytics(machineId, {
      'totalStoppedTime': totalStoppedTime.inSeconds,
      'lastUpdated': now.toIso8601String(),
    });
  }

  // Method to aggregate monthly and yearly statistics from daily data
  static Future<void> aggregateMonthlyYearlyStats(String machineId) async {
    final now = DateTime.now();
    final analytics = await getMachineAnalytics(machineId);

    if (analytics != null) {
      // Aggregate monthly data
      final monthlyStoppedTime = <String, Duration>{};
      for (final entry in analytics.dailyStoppedTime.entries) {
        final dateParts = entry.key.split('-');
        if (dateParts.length == 3) {
          final monthKey = '${dateParts[0]}-${dateParts[1]}';
          monthlyStoppedTime.update(
            monthKey,
            (existing) => existing + entry.value,
            ifAbsent: () => entry.value,
          );
        }
      }

      // Aggregate yearly data
      final yearlyStoppedTime = <String, Duration>{};
      for (final entry in analytics.dailyStoppedTime.entries) {
        final dateParts = entry.key.split('-');
        if (dateParts.length == 3) {
          final yearKey = dateParts[0];
          yearlyStoppedTime.update(
            yearKey,
            (existing) => existing + entry.value,
            ifAbsent: () => entry.value,
          );
        }
      }

      await updateMachineAnalytics(machineId, {
        'monthlyStoppedTime': MachineAnalytics.durationMapToJson(
          monthlyStoppedTime,
        ),
        'yearlyStoppedTime': MachineAnalytics.durationMapToJson(
          yearlyStoppedTime,
        ),
        'lastUpdated': now.toIso8601String(),
      });
    }
  }

  static Future<void> incrementStoppedTimesRealtime(
    String machineId,
    int seconds,
  ) async {
    final analytics = await getMachineAnalytics(machineId);
    if (analytics == null) return;
    final now = DateTime.now();
    await updateMachineAnalytics(machineId, {
      'totalStoppedTime': analytics.totalStoppedTime.inSeconds + seconds,
      'stoppedReadyForWorkTime':
          analytics.stoppedReadyForWorkTime.inSeconds + seconds,
      'lastUpdated': now.toIso8601String(),
    });
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class IssueAssignmentListener {
  final String issueId;
  final void Function()? onAssigned;
  final void Function()? onResolved;
  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
  _subscription;
  bool _wasAssigned = false;
  bool _wasResolved = false;

  IssueAssignmentListener({
    required this.issueId,
    this.onAssigned,
    this.onResolved,
  }) {
    _subscription = FirebaseFirestore.instance
        .collection('issues')
        .doc(issueId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            final assigned = data?['assignedMaintenanceId'] != null;
            final resolved = data?['status'] == 'resolved';

            if (assigned && !_wasAssigned) {
              _wasAssigned = true;
              if (onAssigned != null) onAssigned!();
            }
            if (resolved && !_wasResolved) {
              _wasResolved = true;
              if (onResolved != null) onResolved!();
            }
          }
        });
  }

  void dispose() {
    _subscription.cancel();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For debugPrint and kDebugMode
import 'package:intl/intl.dart'; // Import intl for DateFormat

// Payment class (remains the same as your provided version)
class Payment {
  final String id;
  final String residentId;
  final double amount;
  final String
      monthsCovered; // e.g., "Janvier 2024" or "Janvier 2024, Février 2024" (original string)
  final DateTime paymentDate; // Actual date of payment transaction from dialog
  final String residentName;

  Payment({
    required this.id,
    required this.residentId,
    required this.amount,
    required this.monthsCovered,
    required this.paymentDate,
    required this.residentName,
  });

  // Factory constructor to create Payment from Firestore DocumentSnapshot
  factory Payment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Payment(
      id: doc.id, // Get the document ID
      residentId: data['resident_id'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      monthsCovered: data['months_covered'] ?? '',
      // Convert Firestore Timestamp to DateTime for payment_date field
      paymentDate:
          (data['payment_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      residentName: data['resident_name'] ?? 'Unknown',
    );
  }

  // Method to convert Payment object to Map for Firestore (used when *sending* data)
  Map<String, dynamic> toFirestore() {
    return {
      'resident_id': residentId,
      'amount': amount,
      'months_covered': monthsCovered,
      'payment_date':
          Timestamp.fromDate(paymentDate), // Convert DateTime to Timestamp
      'resident_name': residentName,
      // Note: 'months_covered_str' is added internally in addPaymentNew for efficiency
    };
  }
}

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Define the Caisse document reference
  // Use a specific ID like 'current_balance' for the single caisse document
  final DocumentReference<Map<String, dynamic>> _caisseDocRef =
      FirebaseFirestore.instance
          .collection('caisse_status')
          .doc('current_balance');

  // Helper to parse 'months_covered' string (assuming comma-separated "MMMM yyyy")
  // Normalizes to lowercase for consistent matching.
  Set<String> _parseMonthsCovered(String? monthsCoveredStr) {
    if (monthsCoveredStr == null || monthsCoveredStr.isEmpty) {
      return {};
    }
    return monthsCoveredStr
        .toLowerCase()
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  // --- Caisse Methods ---

  // Get a stream of the caisse balance document for real-time updates
  Stream<DocumentSnapshot<Map<String, dynamic>>> getCaisseBalanceStream() {
    return _caisseDocRef.snapshots();
  }

  // Initialize or set the caisse balance
  Future<void> initializeCaisse(double initialBalance) async {
    // Use a transaction to safely check and set the initial balance
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(_caisseDocRef);

      if (snapshot.exists) {
        // Caisse document already exists, update the balance
        debugPrint("Caisse document already exists. Updating balance.");
        transaction.update(_caisseDocRef, {
          'balance': initialBalance,
          'last_updated': FieldValue
              .serverTimestamp(), // Use server timestamp for update time
        });
      } else {
        // Caisse document does not exist, create it
        debugPrint(
            "Caisse document does not exist. Creating with initial balance.");
        transaction.set(_caisseDocRef, {
          'balance': initialBalance,
          'last_updated': FieldValue.serverTimestamp(), // Use server timestamp
          'created_at':
              FieldValue.serverTimestamp(), // Track initial creation time
        });
      }
    }).catchError((e) {
      // Handle transaction errors
      debugPrint("Transaction failed during initializeCaisse: $e");
      throw Exception("Failed to initialize caisse: $e");
    });
  }

  // Update the caisse balance safely using a transaction
  Future<void> updateCaisseBalance(double amountChange) async {
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(_caisseDocRef);

      if (!snapshot.exists || snapshot.data() == null) {
        // If the caisse document is missing, initialization is required first.
        // Throw an error to signal this to the calling code (e.g., UI).
        debugPrint(
            "Caisse document missing during update attempt. Cannot update.");
        throw Exception(
            "Caisse not initialized. Please initialize the caisse first.");
      }

      // Get the current balance safely
      final data = snapshot.data()!;
      final currentBalance = (data['balance'] as num?)?.toDouble() ??
          0.0; // Default to 0.0 if balance field missing/null

      final newBalance = currentBalance +
          amountChange; // Add the change (positive for income, negative for expense)

      // Update the balance and the last updated timestamp
      transaction.update(_caisseDocRef, {
        'balance': newBalance,
        'last_updated': FieldValue.serverTimestamp(),
      });
    }).catchError((e) {
      // Handle transaction errors
      debugPrint("Transaction failed during updateCaisseBalance: $e");
      throw Exception("Failed to update caisse balance: $e");
    });
  }

  // --- Resident Methods ---

  Future<List<Map<String, dynamic>>> getResidentsWithPaymentInfo() async {
    final residentsSnapshot = await _db
        .collection('residents')
        .orderBy('numero') // Assuming 'numero' is the desired order
        .get();

    List<Map<String, dynamic>> residentsData = [];
    final DateFormat monthKeyFormat =
        DateFormat('MMMM yyyy', 'fr_FR'); // Consistent key format

    for (var residentDoc in residentsSnapshot.docs) {
      Map<String, dynamic> resident = residentDoc.data();
      resident['id'] = residentDoc.id; // Add the document ID

      // Convert resident's created_at to DateTime for UI/logic consistency
      if (resident['created_at'] is Timestamp) {
        resident['created_at_dt'] =
            (resident['created_at'] as Timestamp).toDate();
      } else if (resident['created_at'] is DateTime) {
        // Check if already DateTime
        resident['created_at_dt'] = resident['created_at'];
      } else {
        if (kDebugMode) {
          print(
              "Warning: Resident ${residentDoc.id} 'created_at' is not a Timestamp or DateTime. Defaulting.");
        }
        resident['created_at_dt'] = DateTime.now(); // Fallback
      }

      // Fetch payments for the current resident
      final paymentsSnapshot = await _db
          .collection('payments')
          .where('resident_id', isEqualTo: residentDoc.id)
          .get();

      List<Map<String, dynamic>> paymentsList =
          paymentsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add payment ID

        // Convert payment_date to DateTime and store as payment_date_dt
        if (data['payment_date'] is Timestamp) {
          data['payment_date_dt'] =
              (data['payment_date'] as Timestamp).toDate();
        } else if (data['payment_date'] is DateTime) {
          // Check if already DateTime
          data['payment_date_dt'] = data['payment_date'];
        } else {
          if (kDebugMode) {
            print(
                "Warning: Payment ${doc.id} 'payment_date' is not a Timestamp. Defaulting.");
          }
          data['payment_date_dt'] = DateTime.now(); // Fallback
        }

        // Ensure other fields are correctly typed/handled if needed later
        data['amount_paid'] = (data['amount'] ?? 0.0).toDouble();
        data['months_covered_str'] =
            data['months_covered']?.toString() ?? ''; // Get the original string

        return data; // Return the processed map
      }).toList();
      resident['payments'] =
          paymentsList; // Attach processed payments list to resident

      // --- Calculate montant_restant based on months_covered ---
      DateTime registrationDate =
          resident['created_at_dt']; // Already a DateTime
      double monthlyDue = (resident['monthly_due'] ?? 0.0).toDouble();
      DateTime now = DateTime.now();

      // 1. Get all unique "paid month keys" for this resident (normalized to lowercase)
      Set<String> paidMonthKeys = {};
      for (var payment in paymentsList) {
        // Use the stored 'months_covered_str' which was normalized on save
        paidMonthKeys
            .addAll(_parseMonthsCovered(payment['months_covered_str']));
      }

      // 2. Calculate total due based on unpaid months from registration up to current month (inclusive)
      double calculatedMontantRestant = 0;
      DateTime monthIterator = DateTime(registrationDate.year,
          registrationDate.month, 1); // Start from the first day of reg month
      DateTime endIterationMonth = DateTime(now.year, now.month,
          1); // Iterate up to the first day of the current month

      // Loop through each month from registration month up to the current month
      while (monthIterator.isBefore(endIterationMonth) ||
          monthIterator.isAtSameMomentAs(endIterationMonth)) {
        // Generate the key for the current month in the iteration (normalized to lowercase)
        String currentMonthKey =
            monthKeyFormat.format(monthIterator).toLowerCase();

        // If this month is *not* found in the set of paid months, add the monthly due to the rest
        if (!paidMonthKeys.contains(currentMonthKey)) {
          calculatedMontantRestant += monthlyDue;
        }

        // Move to the first day of the next month
        monthIterator =
            DateTime(monthIterator.year, monthIterator.month + 1, 1);
      }

      resident['montant_restant'] = calculatedMontantRestant;
      // --- End Calculation ---

      residentsData.add(
          resident); // Add the resident map with calculated data to the list
    }

    return residentsData; // Return the list of processed resident maps
  }

  Future<DocumentReference> addResident({
    required String numero,
    required String type,
    required double monthlyDue,
    required String name,
  }) async {
    // Input validation recommended here in a real app
    try {
      return await _db.collection('residents').add({
        'numero': numero,
        'type': type,
        'monthly_due': monthlyDue,
        'name': name,
        'created_at': FieldValue
            .serverTimestamp(), // Use server timestamp for consistency
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error in addResident: $e');
      }
      rethrow; // Re-throw the exception for the UI to handle
    }
  }

  Future<void> deleteResident(String id) async {
    try {
      // Use a batch write to delete the resident and all associated payments atomically
      WriteBatch batch = _db.batch();

      // Add the resident document deletion to the batch
      batch.delete(_db.collection('residents').doc(id));

      // Find and add all associated payment documents deletions to the batch
      final paymentsQuery = await _db
          .collection('payments')
          .where('resident_id', isEqualTo: id)
          .get();
      for (var doc in paymentsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();

      if (kDebugMode) {
        print("Successfully deleted resident $id and their payments.");
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting resident and payments: $e');
      }
      rethrow; // Re-throw the exception
    }
  }

  // Future<List<Payment>> getPayments() async { ... } // Keep if needed elsewhere

  // Add Payment - Now accepts specific paymentDate and includes Caisse update
  Future<Payment> addPaymentNew({
    required String residentId,
    required double amount,
    required String
        monthsCovered, // Expects string like "Janvier 2024" or "Janvier 2024, Février 2024"
    required String residentName,
    required DateTime paymentDate, // Accept the specific date from the dialog
  }) async {
    try {
      final paymentData = {
        'resident_id': residentId,
        'amount': amount,
        'months_covered': monthsCovered
            .trim(), // Store trimmed version of the original string
        'payment_date':
            Timestamp.fromDate(paymentDate), // Use the date from the dialog
        'resident_name': residentName,
        // Add a normalized string for easier searching/filtering/parsing in getResidentsWithPaymentInfo
        'months_covered_str': monthsCovered
            .toLowerCase()
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .join(','),
      };

      // Add the payment document to Firestore
      final docRef = await _db.collection('payments').add(paymentData);

      // --- Update Caisse Balance (Add payment amount) ---
      try {
        // Add the payment amount to the caisse balance using a transaction
        await updateCaisseBalance(amount);
        debugPrint("Caisse balance updated by +$amount after payment.");
      } catch (e) {
        debugPrint(
            "Warning: Failed to update caisse balance after adding payment ${docRef.id}: $e");
        // Decide how to handle this: log, maybe alert user that Caisse is out of sync?
        // The payment *was* added successfully, only the caisse update failed.
        // For now, we just log the warning and continue.
      }
      // --- End Update Caisse Balance ---

      // Re-fetch the document to get the final state including the server timestamp if used
      // (though we used the dialog's date for 'payment_date', serverTimestamp might be used elsewhere or just good practice)
      final newDocSnapshot = await docRef.get();
      return Payment.fromFirestore(
          newDocSnapshot); // Return the created Payment object
    } catch (e) {
      if (kDebugMode) {
        print('Error adding payment: $e');
      }
      throw Exception('Failed to add payment: ${e.toString()}'); // Re-throw
    }
  }

  // --- Expense Methods ---

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final snapshot = await _db
        .collection('expenses')
        .orderBy('created_at', descending: true) // Order by creation date
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // Include document ID

      // Convert created_at to DateTime
      if (data['created_at'] is Timestamp) {
        data['created_at_dt'] = (data['created_at'] as Timestamp).toDate();
      } else if (data['created_at'] is DateTime) {
        data['created_at_dt'] = data['created_at'];
      } else {
        if (kDebugMode) {
          print(
              "Warning: Expense ${doc.id} 'created_at' is not a Timestamp. Defaulting.");
        }
        data['created_at_dt'] = DateTime.now(); // Fallback
      }

      return data; // Return the processed map
    }).toList();
  }

  Future<DocumentReference> addExpense({
    required String name,
    required double amount,
    required String description,
  }) async {
    try {
      // Add the expense document to Firestore
      final docRef = await _db.collection('expenses').add({
        'name': name,
        'amount': amount,
        'description': description,
        'created_at': FieldValue.serverTimestamp(), // Use server timestamp
      });

      // --- Update Caisse Balance (Subtract expense amount) ---
      try {
        // Subtract the expense amount from the caisse balance using a transaction
        // Pass a negative amount to updateCaisseBalance
        await updateCaisseBalance(-amount);
        debugPrint("Caisse balance updated by -$amount after expense.");
      } catch (e) {
        debugPrint(
            "Warning: Failed to update caisse balance after adding expense ${docRef.id}: $e");
        // Handle error as appropriate (logging, user alert)
      }
      // --- End Update Caisse Balance ---

      return docRef; // Return the document reference
    } catch (e) {
      if (kDebugMode) {
        print('Error in addExpense: $e');
      }
      rethrow; // Re-throw
    }
  }

  Future<void> deleteExpense(String id) async {
    // Use String for Firestore ID
    try {
      // Optional: If deleting an expense, should the amount be added back to the caisse?
      // This makes delete logic more complex. For now, delete does NOT affect caisse.
      await _db.collection('expenses').doc(id).delete();
      if (kDebugMode) {
        print("Successfully deleted expense $id.");
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting expense: $e');
      }
      rethrow; // Re-throw
    }
  }
}

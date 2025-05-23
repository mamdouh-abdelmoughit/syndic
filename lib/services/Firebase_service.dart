import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// Keep your Payment class (or adapt if needed)
class Payment {
  final String id; // Use String for Firestore IDs
  final String residentId;
  final double amount;
  final String monthsCovered;
  final DateTime paymentDate;
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
      // Convert Firestore Timestamp to DateTime
      paymentDate: (data['payment_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      residentName: data['resident_name'] ?? 'Unknown', // Handle missing denormalized data
    );
  }

  // Method to convert Payment object to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'resident_id': residentId,
      'amount': amount,
      'months_covered': monthsCovered,
      'payment_date': Timestamp.fromDate(paymentDate), // Convert DateTime to Timestamp
      'resident_name': residentName,
    };
  }
}


class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Resident Methods ---

  Future<List<Map<String, dynamic>>> getResidentsWithPaymentInfo() async {
    // 1. Get all residents
    final residentsSnapshot = await _db.collection('residents')
                                      .orderBy('numero') // Assuming 'numero' is still used for ordering
                                      .get();

    List<Map<String, dynamic>> residentsData = [];

    // 2. For each resident, get their payments (This can be inefficient for many residents - see notes below)
    for (var residentDoc in residentsSnapshot.docs) {
      Map<String, dynamic> resident = residentDoc.data();
      resident['id'] = residentDoc.id; // Add the document ID

      final paymentsSnapshot = await _db.collection('payments')
                                        .where('resident_id', isEqualTo: residentDoc.id)
                                        .get();

      List<Map<String, dynamic>> payments = paymentsSnapshot.docs.map((doc) {
         final data = doc.data();
         // Convert Timestamps if necessary for calculation logic
         if (data['payment_date'] is Timestamp) {
           data['payment_date_dt'] = (data['payment_date'] as Timestamp).toDate();
         }
         // Map other fields if needed for calculation (e.g., amount)
         data['amount_paid'] = (data['amount'] ?? 0.0).toDouble(); // Assuming 'amount' field holds paid amount
         // Add month/year if you need them derived from payment_date for calculation
         if(data['payment_date_dt'] != null){
            data['month'] = data['payment_date_dt'].month;
            data['year'] = data['payment_date_dt'].year;
         }
         return data;
      }).toList();

      resident['payments'] = payments; // Add payments list to the resident map

      // --- Calculate montant_restant (Logic adapted from Supabase version) ---
      // Ensure fields exist and have defaults
      double monthlyDue = (resident['monthly_due'] ?? 0.0).toDouble();
      DateTime registrationDate = (resident['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(); // Handle null/missing

      DateTime now = DateTime.now();
      int currentMonth = now.month;
      int currentYear = now.year;

      // Calculate months since registration (inclusive of the registration month potentially, adjust as needed)
      // Be careful with edge cases (e.g., registration this month)
      int monthsDiff = (currentYear - registrationDate.year) * 12 + (currentMonth - registrationDate.month);
      if (monthsDiff < 0) monthsDiff = 0; // Cannot have negative months
      // If you want to include the current month fully, add 1, e.g., +1. Check your business logic.
      // Or maybe calculate based on *next* month due date? Clarify requirement. Let's assume months passed for now.

      double totalDue = monthlyDue * monthsDiff; // Potentially monthsDiff + 1 depending on logic

      double totalPaid = payments.fold(0.0, (sum, payment) {
        // Use the derived DateTime for comparison
         DateTime? paymentDt = payment['payment_date_dt'];
         if(paymentDt != null) {
            // Your original logic checked payment month/year columns. Now check payment_date.
            // Only sum payments made for periods up to the current month/year.
            if (paymentDt.year < currentYear ||
                (paymentDt.year == currentYear && paymentDt.month <= currentMonth)) {
                 return sum + (payment['amount_paid'] ?? 0.0).toDouble();
             }
         }
         // Alternative: If payment relates to specific months covered:
         // Parse 'months_covered' and check if it falls within the required range.
         // This calculation depends heavily on your exact requirements for "due" vs "paid".

        return sum;
      });

      resident['montant_restant'] = totalDue - totalPaid;
      // --- End Calculation ---

      residentsData.add(resident);
    }

    // **Performance Note:** Fetching payments for each resident individually (N+1 problem)
    // can be slow. Alternatives:
    // 1. Fetch ALL payments once, then filter/group them client-side. Better for moderate data.
    // 2. Use Firestore Subcollections: Store payments within each resident document (`residents/{residentId}/payments/{paymentId}`). More complex queries (Collection Group Queries) needed to get *all* payments across residents.
    // 3. Denormalize aggregated data (e.g., store `total_paid` on the resident document, update with Cloud Functions). Most complex but scalable.

    return residentsData;
  }


  Future<DocumentReference> addResident({ // Returns DocumentReference which contains the ID
    required String numero,
    required String type,
    required double monthlyDue,
    required String name, // Added name based on payment functions
  }) async {
    // Input validation recommended here
    return _db.collection('residents').add({
      'numero': numero,
      'type': type,
      'monthly_due': monthlyDue,
      'name': name, // Store the name
      'created_at': FieldValue.serverTimestamp(), // Use server timestamp
    });
  }

  Future<void> deleteResident(String id) async {
    // **Caution:** Need to decide if deleting a resident should also delete their payments.
    // If so, you need a more complex deletion process (e.g., a Cloud Function or batch write).
    try {
      await _db.collection('residents').doc(id).delete();
      // Optionally, query and delete associated payments here (or use Cloud Function trigger)
    } catch (e) {
      debugPrint('Error deleting resident: $e');
      rethrow;
    }
  }

  // --- Payment Methods --- (Using the new structure based on Payment class)

  // Get Payments (similar to your Supabase getPayments)
  Future<List<Payment>> getPayments() async {
    try {
      final snapshot = await _db.collection('payments')
          .orderBy('payment_date', descending: true)
          .get();

      // Already includes resident_name (denormalized)
      return snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList();

    } catch (e) {
      debugPrint('Error getting payments: $e');
      throw Exception('Failed to load payments: $e');
    }
  }

  // Add Payment (similar to your Supabase addPaymentNew)
  Future<Payment> addPaymentNew({
    required String residentId, // Use Firestore Document ID (String)
    required double amount,
    required String monthsCovered,
    // Assuming you fetch resident name beforehand or pass it in
    required String residentName,
  }) async {
    try {
      // No need to fetch resident name if passed in or already known.
      // If you only have residentId, fetch name first (adds latency):
      // final residentDoc = await _db.collection('residents').doc(residentId).get();
      // final residentName = residentDoc.data()?['name'] ?? 'Unknown';

      final paymentData = {
        'resident_id': residentId,
        'amount': amount,
        'months_covered': monthsCovered,
        'payment_date': FieldValue.serverTimestamp(), // Use server timestamp
        'resident_name': residentName, // Store denormalized name
      };

      final docRef = await _db.collection('payments').add(paymentData);

      // To return the full Payment object, we need the timestamp assigned by the server.
      // We either return just the ID or re-fetch the document. Fetching is more accurate.
      final newDocSnapshot = await docRef.get();
      return Payment.fromFirestore(newDocSnapshot);

    } catch (e) {
      debugPrint('Error adding payment: $e');
      throw Exception('Failed to add payment: $e');
    }
  }

  // --- Expense Methods ---

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final snapshot = await _db.collection('expenses')
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs.map((doc) {
       final data = doc.data();
       data['id'] = doc.id; // Include document ID
       // Convert Timestamp to DateTime if needed for display
       if (data['created_at'] is Timestamp) {
           data['created_at_dt'] = (data['created_at'] as Timestamp).toDate();
       }
       return data;
    }).toList();
  }

  Future<DocumentReference> addExpense({
    required String name,
    required double amount,
    required String description,
  }) async {
    try {
      return await _db.collection('expenses').add({
        'name': name,
        'amount': amount,
        'description': description,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error in addExpense: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async { // Use String for Firestore ID
    try {
      await _db.collection('expenses').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      rethrow;
    }
  }
}
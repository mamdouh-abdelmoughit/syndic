// lib/pages/unpaid_months_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Note: This page no longer takes onPayMonth or onGenerateReceipt callbacks.
// It signals the chosen action back to the calling page (ResidentPage) via Navigator.pop.

class UnpaidMonthsPage extends StatefulWidget {
  final String residentId; // Keep id for potential future direct actions if needed
  final String residentName;
  final String residentNumero;
  final double monthlyDue;
  final DateTime registrationDate;
  final List<Map<String, dynamic>> payments; // Raw payments list

  const UnpaidMonthsPage({
    super.key,
    required this.residentId,
    required this.residentName,
    required this.residentNumero,
    required this.monthlyDue,
    required this.registrationDate,
    required this.payments,
    // --- REMOVED CALLBACK PARAMETERS ---
    // required Future<Payment?> Function(String, double) onPayMonth,
    // required Future<File?> Function(String, double, DateTime) onGenerateReceipt,
    // --- END REMOVED PARAMETERS ---
  });

  @override
  State<UnpaidMonthsPage> createState() => _UnpaidMonthsPageState();
}

class _UnpaidMonthsPageState extends State<UnpaidMonthsPage> {
  late Set<String> _paidMonthKeys;
  late List<DateTime> _displayMonths;
  final DateFormat _monthKeyFormatter = DateFormat('MMMM yyyy', 'fr_FR');
  final DateFormat _shortMonthFormatter = DateFormat('MMM', 'fr_FR');

  // No _isProcessing state or disposal needed here anymore as actions pop the page

  @override
  void initState() {
    super.initState();
    // Initialize data when the page is created
    _updateCalendarData();
  }

  // Note: We don't need to re-run _updateCalendarData if the widget's 'payments'
  // property changes *while this page is active*, because UnpaidMonthsPage
  // is pushed and then popped. A new instance is created each time you
  // navigate to it from ResidentPage, receiving the fresh payments list then.

  void _updateCalendarData() {
    _paidMonthKeys = _getPaidMonthKeys();
    _displayMonths = _getDisplayMonths();
  }

  // Helper to get paid month keys from the payments list, normalizes to lowercase
  Set<String> _getPaidMonthKeys() {
    Set<String> paidKeys = {};
    for (var payment in widget.payments) {
      // Use the stored 'months_covered_str' field added in FirebaseService for this purpose
      String? monthsCoveredStr = payment['months_covered_str']?.toString();
      if (monthsCoveredStr != null && monthsCoveredStr.isNotEmpty) {
        // Split the normalized string by commas and add individual months to the set
        List<String> individualMonths = monthsCoveredStr
            .split(',') // Already lowercased and trimmed when saved by service
            .where((s) => s.isNotEmpty)
            .toList();
        paidKeys.addAll(individualMonths);
      } else {
        // Fallback: Try to parse the original 'months_covered' field if 'months_covered_str' is missing
         String? originalMonthsStr = payment['months_covered']?.toString();
         if (originalMonthsStr != null && originalMonthsStr.isNotEmpty) {
            if (kDebugMode) {
              print("Warning: 'months_covered_str' missing for payment ${payment['id']}. Parsing original 'months_covered'.");
            }
            paidKeys.addAll(_parseMonthsCovered(originalMonthsStr)); // Use helper from FirebaseService logic
         }
      }
    }
    return paidKeys;
  }

  // Helper function (similar to FirebaseService) to parse old 'months_covered' if 'months_covered_str' is missing
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


  // Helper to determine which months to display in the calendar grid
  List<DateTime> _getDisplayMonths() {
    List<DateTime> displayMonths = [];
    DateTime now = DateTime.now();

    // Calculate the range of months to display:
    // Start: January of the registration year
    DateTime calendarStartDate = DateTime(widget.registrationDate.year, 1, 1);

    // End: December of the current year + maybe a couple of months into the next year for context
    DateTime calendarEndDate = DateTime(now.year, 12, 1);
    // Optional: Extend into the next year, e.g., show up to March of next year
    // calendarEndDate = DateTime(now.year + 1, 3, 1); // Example: Show up to March of next year

    // Ensure the calendar does not start before the registration month if the registration is later in the registration year
    DateTime firstMonthToConsider = DateTime(widget.registrationDate.year, widget.registrationDate.month, 1);
     if (calendarStartDate.isBefore(firstMonthToConsider)) {
        calendarStartDate = firstMonthToConsider; // Start from registration month if it's later than Jan
     }


    DateTime currentMonthIterator = DateTime(calendarStartDate.year, calendarStartDate.month, 1); // Start from the first day of the start month
    const int maxMonthsToShow = 60; // Safety limit (e.g., 5 years)

    while (!currentMonthIterator.isAfter(calendarEndDate) && displayMonths.length < maxMonthsToShow) {
      displayMonths.add(currentMonthIterator);
      // Move iterator to the first day of the next month
      currentMonthIterator = DateTime(currentMonthIterator.year, currentMonthIterator.month + 1, 1);
    }

    return displayMonths;
  }

  // Helper to find payment details for a specific month key (normalized lowercase)
  // This is needed here because UnpaidMonthsPage needs payment date/amount for the "Reçu" action pop
  Map<String, dynamic>? _getPaymentDetailsForMonth(String targetMonthKeyFormatted) {
     // Normalize the target month key for consistent matching
     String normalizedTargetMonthKey = targetMonthKeyFormatted.trim().toLowerCase();
     // Use the same logic as in getPaidMonthKeys
     for (var payment in widget.payments) {
        // Ensure the payment map contains the processed 'months_covered_str' field
        String? monthsCoveredStr = payment['months_covered_str']?.toString();
        if (monthsCoveredStr != null && monthsCoveredStr.isNotEmpty) {
           // Split, trim, lowercase the stored string
           List<String> coveredMonths = monthsCoveredStr.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
           // Check if the list of months covered by this payment contains the target month
           if (coveredMonths.contains(normalizedTargetMonthKey)) {
              return payment; // Found the payment that covers this specific month
           }
        }
     }
     return null; // No payment found covering this month
  }


  @override
  Widget build(BuildContext context) {
    // Recalculate total due based on the *displayed* months that are unpaid and past/current
    final DateTime now = DateTime.now();
    final DateTime firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
    final DateTime firstDayOfRegistrationMonth = DateTime(widget.registrationDate.year, widget.registrationDate.month, 1);

    double totalDueCalculated = 0;
    int unpaidMonthsCount = 0;
    for (var monthDate in _displayMonths) {
      // Only consider months from registration up to the current month
      if (monthDate.isBefore(firstDayOfRegistrationMonth) ||
          monthDate.isAfter(firstDayOfCurrentMonth.add(const Duration(days: 30)))) // Check slightly past current month start
      {
         continue; // Skip months before registration or truly in the future
      }

      // Generate the key for the current month (normalized lowercase for lookup)
      String currentMonthKeyNormalized = _monthKeyFormatter.format(monthDate).toLowerCase();

      // If this month is not found in the set of paid months, it's unpaid and due (because it's not in the future)
      if (!_paidMonthKeys.contains(currentMonthKeyNormalized)) {
        totalDueCalculated += widget.monthlyDue;
        unpaidMonthsCount++;
      }
    }


    return Scaffold(
      appBar: AppBar(
        title: Text('Calendrier Paiements: ${widget.residentNumero}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          // Resident Info Card with calculated total due based on calendar
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Résident: ${widget.residentName}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Montant Mensuel: ${widget.monthlyDue.toStringAsFixed(2)} DH',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(height: 20, thickness: 0.5),
                  Text(
                    // Display the total due based on unpaid months in the displayed calendar range
                    'Total Actuellement Dû (selon calendrier): ${totalDueCalculated.toStringAsFixed(2)} DH',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: totalDueCalculated > 0
                              ? Theme.of(context).colorScheme.error
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (unpaidMonthsCount == 0 && totalDueCalculated == 0 && _displayMonths.any((month) => month.isBefore(firstDayOfCurrentMonth.add(const Duration(days:30))) && !month.isBefore(firstDayOfRegistrationMonth)))
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text("Tous les mois jusqu'à présent sont payés!",
                          style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500)),
                    ),
                ],
              ),
            ),
          ),

          // Calendar Grid
          Expanded(
            child: _displayMonths.isEmpty
                ? const Center(child: Text('Aucun mois à afficher.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // 3 months per row
                      childAspectRatio: 1.0, // Roughly square tiles
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: _displayMonths.length,
                    itemBuilder: (context, index) {
                      final monthDate = _displayMonths[index];
                      // Key for display and returning via pop (e.g., "Janvier 2024")
                      final String monthKeyFormatted = _monthKeyFormatter.format(monthDate);
                      // Key for internal lookup (normalized lowercase)
                      final String monthKeyNormalized = monthKeyFormatted.toLowerCase();

                      // Determine month status based on paid keys and date relative to now/registration
                      final bool isPaid = _paidMonthKeys.contains(monthKeyNormalized);
                      final bool isBeforeRegistration = monthDate.isBefore(firstDayOfRegistrationMonth);
                      final bool isFutureMonth = monthDate.isAfter(firstDayOfCurrentMonth); // Month after the current one

                      Color tileColor = Colors.white;
                      Color borderColor = Colors.grey.shade300;
                      IconData statusIcon = Icons.help_outline; // Default/Unknown status
                      Color statusIconColor = Colors.grey;
                      String statusText = '';

                      List<Widget> actionWidgets = []; // List of buttons/actions

                      if (isBeforeRegistration) {
                        // Month before resident registration
                        tileColor = Colors.grey.shade200;
                        borderColor = Colors.grey.shade400;
                        statusIcon = Icons.block;
                        statusIconColor = Colors.grey.shade600;
                        statusText = 'Avant Enreg.';
                      } else if (isPaid) {
                        // Paid month (on or after registration)
                        tileColor = Colors.green.shade100;
                        borderColor = Colors.green.shade400;
                        statusIcon = Icons.check_circle_outline;
                        statusIconColor = Colors.green.shade700;
                        statusText = 'Payé';
                        // Add "Reçu" button if paid
                        actionWidgets.add(_actionButton(
                          icon: Icons.receipt_long,
                          label: 'Reçu',
                          color: Colors.teal.shade600,
                           // Pop with 'show_receipt' action and the month key
                          onPressed: () => Navigator.pop(context, {'action': 'show_receipt', 'month': monthKeyFormatted}),
                        ));
                      } else {
                        // Not paid and on or after registration
                        if (isFutureMonth) {
                          // Future month (not paid, not due yet)
                          tileColor = Colors.blue.shade100;
                          borderColor = Colors.blue.shade400;
                          statusIcon = Icons.hourglass_empty;
                          statusIconColor = Colors.blue.shade700;
                          statusText = 'À Venir';
                          // Allow paying future months
                           actionWidgets.add(_actionButton(
                             icon: Icons.payment,
                             label: 'Payer',
                             color: Theme.of(context).colorScheme.primary,
                             // Pop with 'pay_month' action and the month key
                             onPressed: () => Navigator.pop(context, {'action': 'pay_month', 'month': monthKeyFormatted}),
                           ));
                        } else {
                          // Past or current month, not paid (due)
                          tileColor = Colors.red.shade100;
                          borderColor = Colors.red.shade400;
                          statusIcon = Icons.error_outline;
                          statusIconColor = Colors.red.shade700;
                          statusText = 'Impayé';
                          // Allow paying due months
                          actionWidgets.add(_actionButton(
                             icon: Icons.payment,
                             label: 'Payer',
                             color: Theme.of(context).colorScheme.primary,
                             // Pop with 'pay_month' action and the month key
                             onPressed: () => Navigator.pop(context, {'action': 'pay_month', 'month': monthKeyFormatted}),
                           ));
                        }
                      }


                      return Card(
                        elevation: 1.5,
                        color: tileColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: borderColor, width: 1.2),
                        ),
                        child: Padding( // Add some internal padding
                          padding: const EdgeInsets.all(4.0), // Reduced padding
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribute space
                            children: [
                              // Month and Year Display
                               Text(
                                  _shortMonthFormatter.format(monthDate).capitalize(), // Capitalize first letter
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14, // Slightly smaller font
                                      color: Colors.black87.withOpacity(0.8)),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  monthDate.year.toString(),
                                  style: TextStyle(
                                      fontSize: 10, // Smaller font
                                      color: Colors.black54.withOpacity(0.7)),
                                   textAlign: TextAlign.center,
                                ),

                              // Status Icon
                                Icon(statusIcon, color: statusIconColor, size: 18), // Consistent icon size
                               // Status Text (Optional, if space permits)
                               // Text(statusText, style: TextStyle(fontSize: 9, color: statusIconColor)),

                              // Action Buttons (if any)
                                if (actionWidgets.isNotEmpty)
                                  // Use a Column for buttons if they are vertical, Wrap if horizontal space is limited
                                  Column( // Using Column for potentially multiple buttons vertical
                                    mainAxisSize: MainAxisSize.min, // Wrap content
                                    children: actionWidgets,
                                  )
                                // else // Placeholder if no actions to maintain similar height - adjust height based on action button size
                                //   const SizedBox(height: 28), // Approx height of an action button

                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Helper widget for the small action buttons
  Widget _actionButton(
      {required IconData icon,
      required String label,
      required Color color,
      VoidCallback? onPressed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0), // Add padding between buttons
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 14, color: Colors.white),
        label: Text(label, style: const TextStyle(fontSize: 9, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          minimumSize: const Size(60, 26), // Adjusted minimum size for slightly more space
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
           elevation: 1, // Smaller elevation
        ),
        onPressed: onPressed, // Pass the onPressed callback (which now pops)
      ),
    );
  }
}

// Keep your StringExtension for capitalization
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    // Capitalize first letter, rest lowercase for consistency with 'MMMM' format
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UnpaidMonthsPage extends StatelessWidget {
  final String residentId;
  final String residentName;
  final String residentNumero;
  final double monthlyDue;
  final DateTime registrationDate;
  final List<Map<String, dynamic>> payments;

  const UnpaidMonthsPage({
    super.key,
    required this.residentId,
    required this.residentName,
    required this.residentNumero,
    required this.monthlyDue,
    required this.registrationDate,
    required this.payments,
  });

  List<DateTime> _getUnpaidMonths() {
    List<DateTime> unpaidMonths = [];
    DateTime now = DateTime.now();
    DateTime currentDate = DateTime(registrationDate.year, registrationDate.month);
    
    // Create a set of paid months for efficient lookup
    Set<String> paidMonths = {};
    for (var payment in payments) {
      if (payment['months_covered'] != null) {
        paidMonths.add(payment['months_covered']);
      }
    }

    // Check each month from registration until now
    while (currentDate.isBefore(DateTime(now.year, now.month + 1))) {
      String monthKey = DateFormat('MMMM yyyy', 'fr_FR').format(currentDate);
      if (!paidMonths.contains(monthKey)) {
        unpaidMonths.add(currentDate);
      }
      currentDate = DateTime(
        currentDate.year + (currentDate.month == 12 ? 1 : 0),
        currentDate.month == 12 ? 1 : currentDate.month + 1,
      );
    }

    return unpaidMonths;
  }

  double _calculateTotalDue(List<DateTime> unpaidMonths) {
    return monthlyDue * unpaidMonths.length;
  }

  @override
  Widget build(BuildContext context) {
    final unpaidMonths = _getUnpaidMonths();
    final totalDue = _calculateTotalDue(unpaidMonths);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mois Non Payés'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          // Resident Info Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Résident: $residentName',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Numéro: $residentNumero',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Montant mensuel: ${monthlyDue.toStringAsFixed(2)} DH',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(),
                  Text(
                    'Total dû: ${totalDue.toStringAsFixed(2)} DH',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Unpaid Months List
          Expanded(
            child: unpaidMonths.isEmpty
                ? Center(
                    child: Text(
                      'Tous les mois sont payés!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: unpaidMonths.length,
                    itemBuilder: (context, index) {
                      final month = unpaidMonths[index];
                      final monthName = DateFormat('MMMM yyyy', 'fr_FR')
                          .format(month)
                          .capitalize();
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .errorContainer,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                          title: Text(monthName),
                          trailing: Text(
                            '${monthlyDue.toStringAsFixed(2)} DH',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
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
}

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
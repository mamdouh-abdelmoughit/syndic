// lib/pages/resident_page.dart

import 'dart:io'; // Needed for File type for PDF generation
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; // For sharing PDF
// Import PDF Generator Service instead of individual receipt pages
import 'package:syndic_app/services/pdf_generator.dart';
import '../services/firebase_service.dart';
import 'package:syndic_app/pages/unpaid_months_page.dart';
import '../widget/add_resident_dialog.dart';
import '../widget/add_payment_dialog.dart';

// Remove receipt_page.dart and recipt_magasin_page.dart imports if not used elsewhere
// import 'package:syndic_app/pages/receipt_page.dart';
// import 'package:syndic_app/pages/recipt_magasin_page.dart';


class ResidentPage extends StatefulWidget {
  const ResidentPage({super.key});

  @override
  State<ResidentPage> createState() => _ResidentPageState();
}

class _ResidentPageState extends State<ResidentPage> {
  late final FirebaseService _firebaseService;
  List<Map<String, dynamic>> _residents = [];
  List<Map<String, dynamic>> _filteredResidents = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _loadResidents();
    _searchController.addListener(() {
      _filterResidents(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadResidents() async {
    // ... (this method remains largely the same, pulling data from FirebaseService)
    try {
      setState(() => _isLoading = true);
      final residents = await _firebaseService.getResidentsWithPaymentInfo();
      if (mounted) {
        setState(() {
          _residents = residents;
          _filterResidents(_searchController.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Ensure error message is helpful and doesn't crash
        String errorMessage = 'Erreur chargement résidents';
        if (e is FirebaseException) {
           errorMessage += ': ${e.message}';
        } else {
           errorMessage += ': ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterResidents(String query) {
    // ... (this method remains the same, filtering _residents list)
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredResidents = List.from(_residents);
      } else {
        _filteredResidents = _residents.where((resident) {
          final numero = resident['numero']?.toString() ?? '';
          // Also allow searching by name if desired
          final name = resident['name']?.toString()?.toLowerCase() ?? '';
          return numero.toLowerCase().contains(lowerCaseQuery) || name.contains(lowerCaseQuery);
        }).toList();
      }
    });
  }

  Future<void> _showAddResidentDialog() async {
    // ... (this method remains the same, adds resident via service)
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddResidentDialog(),
    );

    if (result != null && mounted) {
       // Check for all required fields from the dialog result
       final String? numero = result['numero'];
       final String? type = result['type'];
       final double? monthlyDue = result['monthlyDue'];
       final String? name = result['name'];

       if (numero == null || type == null || monthlyDue == null || name == null || numero.isEmpty || name.isEmpty) {
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Erreur: Informations du résident incomplètes.')),
                );
            }
            return;
       }
      try {
        // Call the service to add the resident
        await _firebaseService.addResident(
          numero: numero,
          type: type,
          monthlyDue: monthlyDue,
          name: name,
        );
        await _loadResidents(); // Refresh the resident list
         if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Résident ajouté avec succès')),
            );
         }
      } catch (e) {
        if (mounted) {
          print("Error adding resident: $e"); // Debug print
          String errorMessage = 'Erreur ajout résident';
           if (e is FirebaseException) {
              errorMessage += ': ${e.message}';
           } else {
              errorMessage += ': ${e.toString()}';
           }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    }
  }

  // --- NEW: Handler for adding a payment (used by DataTable button and Calendar) ---
  // This method now launches the dialog and handles the service call & UI updates
  Future<Payment?> _handleAddPayment(
    String residentId,
    String residentNumero,
    String residentType,
    String residentName, {
    String? initialMonthsCovered, // Optional: pre-fill months field
    double? initialAmount,      // Optional: pre-fill amount field
  }) async {
    // Show the payment dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddPaymentDialog(
        residentId: residentId, // Pass data needed by dialog or for context
        residentNumero: residentNumero,
        residentType: residentType,
        initialMonthsCovered: initialMonthsCovered, // Pass initial values to dialog
        initialAmount: initialAmount?.toStringAsFixed(2), // Pass as string
      ),
    );

    // If dialog was cancelled, result will be null
    if (result == null) {
      // Optional: show a message or just do nothing if cancelled
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajout de paiement annulé.')));
      // }
      return null;
    }

    // Extract data from dialog result
    final double? amount = result['amount'] as double?;
    final String? monthsCovered = result['monthsCovered'] as String?;
    final DateTime? paymentDate = result['paymentDate'] as DateTime?; // Get the selected date

    // Validate required fields from dialog result
    if (amount == null || monthsCovered == null || monthsCovered.isEmpty || paymentDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Informations du paiement manquantes ou invalides.')),
        );
      }
      return null; // Stop if data is missing
    }

    try {
      // Call the service to add the payment and update the Caisse
      final Payment newPayment = await _firebaseService.addPaymentNew(
        residentId: residentId,
        amount: amount,
        monthsCovered: monthsCovered, // Use the string from the dialog
        residentName: residentName,
        paymentDate: paymentDate, // <--- Pass the date from the dialog result
      );

      // Payment added successfully, refresh the resident list to update Montant Restant
      await _loadResidents();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paiement pour "$monthsCovered" ajouté avec succès!')),
        );
        // Optionally navigate to receipt page immediately after successful payment
        // This logic was previously in the dialog but is better here after the service call.
        await _handleGenerateReceipt(
          { // Pass minimal resident data needed by generator
            'numero': residentNumero,
            'name': residentName,
            'type': residentType,
          },
          monthsCovered, // Pass the months string
          amount,        // Pass the amount paid
          paymentDate,   // Pass the date of the payment
        );
      }
      return newPayment; // Return the successful payment object
    } catch (e) {
      if (mounted) {
        print("Error adding payment: $e"); // Debug print
         String errorMessage = 'Erreur ajout paiement';
         if (e is FirebaseException) {
            errorMessage += ': ${e.message}';
         } else {
            errorMessage += ': ${e.toString()}';
         }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
      return null; // Return null to indicate failure
    }
  }


  // --- NEW: Handler for generating and sharing a receipt ---
  Future<File?> _handleGenerateReceipt(
    Map<String, dynamic> residentData, // Contains name, numero, type
    String monthsDescription,          // e.g., "Janvier 2024" or "Jan, Feb 2024"
    double amountPaid,
    DateTime paymentDateOfRecord,      // The date the payment (covering this month/period) was recorded
  ) async {
    final String numero = residentData['numero']?.toString() ?? 'N/A';
    final String name = residentData['name']?.toString() ?? 'N/A';
    final String type = residentData['type']?.toString() ?? 'N/A';

    // Use the PdfGenerator service
    File? pdfFile;
    if (type == 'Magasin') {
      pdfFile = await PdfGenerator.generateMagasinReceipt(
        residentNumero: numero,
        residentName: name,
        residentType: type,
        montantPaye: amountPaid,
        paymentDate: paymentDateOfRecord, // Date of the original payment
        monthsDescription: monthsDescription, // Pass the months string
        // Optional data you might want to pass:
        // yourCityName: "Your City",
        // buildingAddress: "Your Building Address",
      );
    } else { // Appartement
      pdfFile = await PdfGenerator.generateApartmentReceipt(
        residentNumero: numero,
        residentName: name,
        montantPaye: amountPaid,
        paymentDate: paymentDateOfRecord, // Date of the original payment
        monthsDescription: monthsDescription, // Pass the months string
        // Optional data:
        // yourCityName: "Your City",
      );
    }

    // Share the generated PDF
    if (pdfFile != null && mounted) {
      try {
        // Find the render box for positioning the share sheet on iPad
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(pdfFile.path)],
          text: 'Reçu de paiement pour $name ($numero) - $monthsDescription',
          subject: 'Reçu PDF - $monthsDescription',
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        );
      } catch (e) {
         print("Error sharing PDF: $e"); // Debug print
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Erreur lors du partage du reçu PDF: ${e.toString()}')),
            );
         }
      }
      return pdfFile; // Return the file even if sharing failed
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de la génération du reçu PDF.')),
      );
      return null;
    }
    return null; // Should not reach here if pdfFile is null
  }


  Future<void> _deleteResident(String residentId) async {
    // ... (this method remains the same, deletes resident and payments via service)
     final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Voulez-vous vraiment supprimer ce résident ? Cette action est irréversible et supprimera aussi tous ses paiements.'), // Added clarity
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer')),
          ],
        ),
     );

     if (confirm == true && residentId.isNotEmpty && mounted) { // Added residentId check
        try {
          // Call the service to delete resident and their payments
          await _firebaseService.deleteResident(residentId);
          await _loadResidents(); // Refresh the resident list
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Résident supprimé avec succès')),
            );
          }
        } catch (e) {
          if (mounted) {
            print("Error deleting resident: $e"); // Debug print
            String errorMessage = 'Erreur suppression résident';
             if (e is FirebaseException) {
                errorMessage += ': ${e.message}';
             } else {
                errorMessage += ': ${e.toString()}';
             }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        }
     }
  }

  // --- MODIFIED: _showUnpaidMonths to navigate to the calendar page ---
  // It now awaits the result from UnpaidMonthsPage to handle actions (Pay/Receipt)
  void _showUnpaidMonths(Map<String, dynamic> resident) async {
    // Safely extract resident data, handling potential nulls
    DateTime registrationDateTime;
    if (resident['created_at_dt'] is DateTime) {
      registrationDateTime = resident['created_at_dt'] as DateTime;
    } else if (resident['created_at'] is Timestamp) {
      registrationDateTime = (resident['created_at'] as Timestamp).toDate();
    } else {
      print("Warning: 'created_at_dt' is missing for resident ${resident['numero']}. Using current date as fallback.");
      registrationDateTime = DateTime.now();
    }

    final String residentId = resident['id']?.toString() ?? '';
    final String residentNumero = resident['numero']?.toString() ?? 'N/A';
    final String residentType = resident['type']?.toString() ?? 'N/A';
    final String residentName = resident['name']?.toString() ?? 'N/A';
    final double monthlyDue = (resident['monthly_due'] as num?)?.toDouble() ?? 0.0;
    final List<Map<String, dynamic>> payments = List<Map<String, dynamic>>.from(resident['payments'] ?? []);

     // Ensure required data is present before navigating
     if (residentId.isEmpty || residentNumero.isEmpty || residentName.isEmpty) {
         if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Erreur: Informations du résident incomplètes pour afficher le calendrier.')),
            );
         }
         return;
     }


    // Navigate to UnpaidMonthsPage and await its result when it's popped
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnpaidMonthsPage(
          residentId: residentId,
          residentName: residentName,
          residentNumero: residentNumero,
          monthlyDue: monthlyDue,
          registrationDate: registrationDateTime,
          payments: payments, // Pass the payments list
          // UnpaidMonthsPage now returns actions via pop instead of taking callbacks
        ),
      ),
    ); // UnpaidMonthsPage is awaited here

    // --- Handle Result from UnpaidMonthsPage ---
    // Check if a result was returned (not null) and if it's a map with an action
    if (result != null && result is Map<String, dynamic> && mounted) {
       final String? action = result['action'] as String?;
       final String? monthKeyFormatted = result['month'] as String?; // The month string the user clicked

       if (action == 'pay_month' && monthKeyFormatted != null) {
          // User clicked 'Payer' on a specific month tile in UnpaidMonthsPage
          // Launch the standard payment dialog, pre-filling the months field
          await _handleAddPayment( // Use the main payment handler
             residentId,
             residentNumero,
             residentType,
             residentName,
             initialMonthsCovered: monthKeyFormatted, // Pre-fill with the clicked month
             initialAmount: monthlyDue, // Pre-fill with monthly due amount
          );
          // _handleAddPayment already calls _loadResidents and shows Snackbar/Receipt
          // No need to explicitly call _loadResidents() again here unless _handleAddPayment changes.

       } else if (action == 'show_receipt' && monthKeyFormatted != null) {
          // User clicked 'Reçu' on a specific month tile in UnpaidMonthsPage
          // Find the payment details for that month and generate the receipt
          final paymentDetails = _getPaymentDetailsForMonth(payments, monthKeyFormatted); // Find payment in the list

          if (paymentDetails != null && mounted) {
            // Extract details from the found payment record
            final double paidAmount = (paymentDetails['amount_paid'] as num?)?.toDouble() ?? monthlyDue; // Use actual amount paid, fallback to monthly due
            final DateTime paymentDateTime = paymentDetails['payment_date_dt'] as DateTime? ?? DateTime.now(); // Use actual payment date

            // Generate and share the receipt using the details from the payment record
            await _handleGenerateReceipt(
              {'numero': residentNumero, 'name': residentName, 'type': residentType}, // Pass relevant resident data
              monthKeyFormatted, // Pass the clicked month string for the receipt
              paidAmount,
              paymentDateTime,
            );
          } else if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Détails du paiement introuvables pour le reçu de "$monthKeyFormatted".')),
             );
          }
       }
       // If any action was handled, the resident list was likely updated by _handleAddPayment,
       // but if 'show_receipt' was used, _loadResidents wasn't called.
       // Let's ensure a refresh occurs after *any* action is processed, except maybe cancellations.
       // If the dialog was cancelled (result == null), we do nothing.
       // If an action was handled, _loadResidents should be called.
       // _loadResidents is already called inside _handleAddPayment.
       // If the user only views the calendar and hits back, no refresh is needed here.
       // If they click 'Reçu', _loadResidents isn't called by _handleGenerateReceipt.
       // So, call _loadResidents here *if* an action (pay or receipt) was attempted.
       // This ensures the list is updated if a payment was made OR if the user just
       // viewed a receipt and came back.

       // Simple approach: If result is not null, assume something *might* have changed and refresh.
       if (result != null) {
          _loadResidents();
       }
    }
    // If result is null (user just popped UnpaidMonthsPage without clicking an action), do nothing.
  }

    // --- Helper function to find payment details for a specific month ---
    // This helper is needed here in ResidentPage because ResidentPage handles the 'show_receipt' action
    Map<String, dynamic>? _getPaymentDetailsForMonth(List<Map<String, dynamic>> payments, String targetMonthKeyFormatted) {
       // Normalize the target month key for consistent matching
       String normalizedTargetMonthKey = targetMonthKeyFormatted.trim().toLowerCase();
       // Use the same logic as in UnpaidMonthsPage to parse months_covered_str
       for (var payment in payments) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Résidents'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher par Numéro ou Nom', // Updated label
                hintText: 'Entrez le numéro ou nom...', // Updated hint
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          _isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: _filteredResidents.isEmpty && !_isLoading
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Aucun résident trouvé.'
                              : 'Aucun résident ne correspond à "${_searchController.text}".',
                           style: Theme.of(context).textTheme.titleMedium,
                        )
                      )
                    : SingleChildScrollView( // For vertical scrolling of the DataTable if content overflows
                        child: SingleChildScrollView( // For horizontal scrolling of the DataTable
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                             headingRowColor: MaterialStateColor.resolveWith(
                               (states) => Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3)
                             ),
                             dataRowMinHeight: 40, // Adjust row height if needed
                             dataRowMaxHeight: 60,
                            columns: const [
                              DataColumn(label: Text('Numéro', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Nom', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Mensuel', style: TextStyle(fontWeight: FontWeight.bold))), // Shortened
                              DataColumn(label: Text('Restant', style: TextStyle(fontWeight: FontWeight.bold))),  // Shortened
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _filteredResidents.map((resident) {
                              // Safely extract data for display
                              final String residentId = resident['id']?.toString() ?? '';
                              final String numero = resident['numero']?.toString() ?? 'N/A';
                              final String type = resident['type']?.toString() ?? 'N/A';
                              final String name = resident['name']?.toString() ?? 'N/A';
                              final double monthlyDue = (resident['monthly_due'] as num?)?.toDouble() ?? 0.0;
                              // Ensure 'montant_restant' is read correctly (calculated in FirebaseService)
                              final double montantRestant = (resident['montant_restant'] as num?)?.toDouble() ?? 0.0;


                              return DataRow(
                                color: MaterialStateProperty.resolveWith<Color?>(
                                  (Set<MaterialState> states) {
                                    if (montantRestant > 0) return Colors.red.withOpacity(0.10);
                                    if (montantRestant < 0) return Colors.green.withOpacity(0.10); // Optional: highlight overpaid
                                    return null; // No specific color if paid up or default
                                  },
                                ),
                                cells: [
                                  DataCell(Text(numero)),
                                  DataCell(Text(type)),
                                  DataCell(Text(name)),
                                  DataCell(Text('${monthlyDue.toStringAsFixed(2)} DH')),
                                  DataCell(
                                    Text(
                                      '${montantRestant.toStringAsFixed(2)} DH',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: montantRestant > 0
                                            ? Theme.of(context).colorScheme.error // Red for positive restant (owed)
                                            : (montantRestant < 0 ? Colors.green.shade700 : Colors.black87), // Green for negative (overpaid), black/default for 0
                                      ),
                                    ),
                                    onTap: () => _showUnpaidMonths(resident), // Tap cell to see calendar
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min, // Keep row compact
                                      children: [
                                        // Removed: "Add Payment" button
                                        /*
                                        IconButton(
                                          icon: const Icon(Icons.payment_outlined),
                                          color: Theme.of(context).colorScheme.primary,
                                          tooltip: 'Ajouter un paiement',
                                          onPressed: residentId.isNotEmpty
                                            ? () => _handleAddPayment(residentId, numero, type, name)
                                            : null,
                                        ),
                                        */
                                        // "View Calendar" button <-- Keep this one
                                        IconButton(
                                          icon: Icon(Icons.calendar_month_outlined, color: Theme.of(context).colorScheme.secondary), // Changed icon style
                                          tooltip: 'Voir calendrier',
                                          onPressed: () => _showUnpaidMonths(resident), // Opens the calendar page
                                        ),
                                        // "Delete Resident" button <-- Keep this one
                                        IconButton(
                                          icon: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error), // Changed icon style
                                          tooltip: 'Supprimer',
                                          onPressed: residentId.isNotEmpty
                                            ? () => _deleteResident(residentId)
                                            : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddResidentDialog,
        icon: const Icon(Icons.add_business_outlined), // Changed icon style
        label: const Text("Nouveau Résident"),
        // backgroundColor: Theme.of(context).colorScheme.tertiary, // Example custom color
        // foregroundColor: Theme.of(context).colorScheme.onTertiary,
      ),
    );
  }
}
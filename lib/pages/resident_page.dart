import 'package:flutter/material.dart';
import '../services/firebase_service.dart'; // Corrected import path if needed
import 'package:syndic_app/pages/receipt_page.dart';
import 'package:syndic_app/pages/recipt_magasin_page.dart';
import '../widget/add_resident_dialog.dart';
import '../widget/add_payment_dialog.dart'; // Make sure this is updated

class ResidentPage extends StatefulWidget {
  const ResidentPage({super.key});

  @override
  State<ResidentPage> createState() => _ResidentPageState();
}

class _ResidentPageState extends State<ResidentPage> {
  // Use FirebaseService
  late final FirebaseService _firebaseService;
  List<Map<String, dynamic>> _residents = [];
  List<Map<String, dynamic>> _filteredResidents = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Instantiate FirebaseService
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
    try {
      setState(() => _isLoading = true);
      // Use FirebaseService method
      final residents = await _firebaseService.getResidentsWithPaymentInfo();
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _residents = residents;
          // Apply current filter (if any) after loading
          _filterResidents(_searchController.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement résidents: ${e.toString()}')),
        );
        setState(() => _isLoading = false); // Stop loading on error
      }
    }
  }

  void _filterResidents(String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredResidents = List.from(_residents); // Show all if query is empty
      } else {
        _filteredResidents = _residents.where((resident) {
          // Safely access 'numero' and convert to string for comparison
          final numero = resident['numero']?.toString() ?? '';
          return numero.toLowerCase().contains(lowerCaseQuery);
        }).toList();
      }
    });
  }

  Future<void> _showAddResidentDialog() async {
    // IMPORTANT: Ensure AddResidentDialog collects and returns 'name'
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddResidentDialog(), // This dialog MUST return 'name'
    );

    if (result != null && mounted) { // Check mounted after await
       // Ensure required fields are present
       if (result['numero'] == null || result['type'] == null || result['monthlyDue'] == null || result['name'] == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur: Informations du résident manquantes.')),
            );
            return;
       }
      try {
        // Use FirebaseService method, passing the required 'name'
        await _firebaseService.addResident(
          numero: result['numero'],
          type: result['type'],
          monthlyDue: result['monthlyDue'],
          name: result['name'], // Name is required by FirebaseService.addResident
        );
        await _loadResidents(); // Refresh the list
         if(mounted){ // Check mounted again before showing snackbar
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Résident ajouté avec succès')),
            );
         }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur ajout résident: ${e.toString()}')),
          );
        }
      }
    }
  }

  // Updated to use FirebaseService.addPaymentNew and handle required params
  Future<void> _showAddPaymentDialog(
    String residentId, // Firestore ID is String
    String numero,
    String type,
    String name, // Need resident's name
  ) async {
    // IMPORTANT: Ensure AddPaymentDialog collects 'amount' and 'monthsCovered'
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      // Pass necessary info; ensure dialog handles residentId as String
      builder: (context) => AddPaymentDialog(
        residentId: residentId, // Pass String ID
        residentNumero: numero,
        residentType: type,
      ), // This dialog MUST return 'amount' and 'monthsCovered'
    );

    if (result != null && mounted) { // Check mounted after await
       // Ensure required fields from dialog
       if (result['amount'] == null || result['monthsCovered'] == null) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Erreur: Informations du paiement manquantes.')),
           );
           return;
       }

      try {
        // Use FirebaseService.addPaymentNew
        // It requires residentName and monthsCovered
        final Payment newPayment = await _firebaseService.addPaymentNew(
          residentId: residentId,
          amount: result['amount'],
          monthsCovered: result['monthsCovered'], // Get from updated dialog
          residentName: name, // Pass resident's name
        );

        await _loadResidents(); // Refresh the list

        if (mounted) { // Check before showing snackbar/navigating
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paiement ajouté avec succès')),
          );

          // Navigate to the appropriate receipt page using data from newPayment
          if (type == 'Magasin') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReceiptPageMagasin(
                  residentNumero: numero,
                  // Use amount from the payment object
                  montantParMois: newPayment.amount,
                  residentType: type,
                  // Use the actual payment date from the server
                  paymentDate: newPayment.paymentDate,
                  // Pass monthsCovered if the receipt needs it
                  // monthsCovered: newPayment.monthsCovered,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReceiptPage(
                  residentNumero: numero,
                   // Use amount from the payment object
                  montantParMois: newPayment.amount,
                   // Use the actual payment date from the server
                  paymentDate: newPayment.paymentDate,
                  // Pass monthsCovered if the receipt needs it
                  // monthsCovered: newPayment.monthsCovered,
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur ajout paiement: ${e.toString()}')),
          );
        }
      }
    }
  }

  // Method to delete a resident using FirebaseService
  Future<void> _deleteResident(String residentId) async { // ID is String
     // Optional: Show confirmation dialog
     final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Voulez-vous vraiment supprimer ce résident ? Cette action est irréversible.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer')),
          ],
        ),
     );

     if (confirm == true && mounted) { // Check confirm and mounted state
        try {
          // Use FirebaseService method
          await _firebaseService.deleteResident(residentId);
          await _loadResidents(); // Reload the resident list after deletion
          if (mounted) { // Check again before snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Résident supprimé avec succès')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur suppression: ${e.toString()}')),
            );
          }
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résidents'),
        // Example using Theme
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
                labelText: 'Rechercher par Numéro',
                hintText: 'Entrez le numéro d\'appart/magasin...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(8.0),
                ),
                 // Clear button
                 // suffixIcon: _searchController.text.isNotEmpty
                 //    ? IconButton(
                 //        icon: Icon(Icons.clear),
                 //        onPressed: () {
                 //           _searchController.clear();
                 //           _filterResidents(''); // Reset filter
                 //        },
                 //      )
                 //    : null,
              ),
              // onChanged removed as listener is used in initState
            ),
          ),
          _isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator())) // Use Expanded
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
                    : SingleChildScrollView( // Vertical scroll for the table container
                        child: SingleChildScrollView( // Horizontal scroll for the table itself
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                             headingRowColor: WidgetStateColor.resolveWith(
                               (states) => Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3)
                             ),
                             // dataRowMinHeight: 50, // Example styling
                             // dataRowMaxHeight: 60,
                             columnSpacing: 15, // Adjust spacing
                            columns: const [
                              DataColumn(label: Text('Numéro', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Nom', style: TextStyle(fontWeight: FontWeight.bold))), // Added Name Column
                              DataColumn(label: Text('Montant Mensuel', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Montant Restant', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _filteredResidents.map((resident) {
                              // Safely access resident data with null checks and defaults
                              final String numero = resident['numero']?.toString() ?? 'N/A';
                              final String type = resident['type']?.toString() ?? 'N/A';
                              final String name = resident['name']?.toString() ?? 'N/A'; // Access name
                              final double monthlyDue = (resident['monthly_due'] as num?)?.toDouble() ?? 0.0;
                              final double montantRestant = (resident['montant_restant'] as num?)?.toDouble() ?? 0.0;
                              final String residentId = resident['id']?.toString() ?? ''; // Ensure ID is String

                              return DataRow(
                                color: WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) {
                                    // Example: Highlight rows with amounts remaining
                                     if (montantRestant > 0) return Colors.red.withOpacity(0.1);
                                    return null; // Use default value for other states and conditions.
                                  },
                                ),
                                cells: [
                                  DataCell(Text(numero)),
                                  DataCell(Text(type)),
                                  DataCell(Text(name)), // Display name
                                  DataCell(Text('${monthlyDue.toStringAsFixed(2)} DH')),
                                  DataCell(
                                    Text(
                                      '${montantRestant.toStringAsFixed(2)} DH',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: montantRestant > 0
                                            ? Colors.redAccent
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min, // Prevent row expanding unnecessarily
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.payment),
                                          color: Theme.of(context).colorScheme.primary,
                                          tooltip: 'Ajouter un paiement',
                                          // Pass String ID, numero, type, and name
                                          onPressed: residentId.isNotEmpty
                                            ? () => _showAddPaymentDialog(residentId, numero, type, name)
                                            : null, // Disable if ID is missing
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          color: Theme.of(context).colorScheme.error,
                                          tooltip: 'Supprimer le résident',
                                          // Pass String ID
                                          onPressed: residentId.isNotEmpty
                                            ? () => _deleteResident(residentId)
                                            : null, // Disable if ID is missing
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
        icon: const Icon(Icons.add),
        label: const Text("Ajouter Résident"),
        // backgroundColor: Theme.of(context).colorScheme.primary,
        // foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}
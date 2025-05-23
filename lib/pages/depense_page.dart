import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import '../services/firebase_service.dart'; // Ensure this path is correct
import '../widget/add_expense_dialog.dart';

class DepensePage extends StatefulWidget {
  const DepensePage({super.key});

  @override
  State<DepensePage> createState() => _DepensePageState();
}

class _DepensePageState extends State<DepensePage> {
  // Use FirebaseService
  late final FirebaseService _firebaseService;
  List<Map<String, dynamic>> _expenses = [];
  Map<String, dynamic>? _selectedExpense;
  bool _isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    // Instantiate FirebaseService
    _firebaseService = FirebaseService();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    if (!mounted) return; // Check if widget is still mounted
    setState(() => _isLoading = true);
    try {
      final expenses = await _firebaseService.getExpenses();
      if (mounted) { // Check again after await
        setState(() {
          _expenses = expenses;
          _isLoading = false;
          // If the selected expense is no longer in the list after refresh, clear selection
          if (_selectedExpense != null &&
              !_expenses.any((exp) => exp['id'] == _selectedExpense!['id'])) {
            _selectedExpense = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement dépenses: ${e.toString()}')),
        );
        setState(() => _isLoading = false); // Stop loading on error
      }
    }
  }

  Future<void> _showAddExpenseDialog() async {
    showDialog<void>( // Use void type if dialog doesn't return a specific value
      context: context,
      builder: (context) {
        return AddExpenseDialog(
          // The implementation inside onAdd now uses FirebaseService
          onAdd: (String name, double amount, String description) async {
            try {
              await _firebaseService.addExpense(
                  name: name, amount: amount, description: description);
              // No need to manually close dialog here if AddExpenseDialog handles it
              _fetchExpenses(); // Refresh the list after adding
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Dépense ajoutée avec succès')),
                 );
              }
            } catch (e) {
              if (mounted) {
                 // Close dialog manually if error occurs *before* it closes itself
                 // Navigator.of(context).pop(); // Optional: depends on dialog logic
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Erreur ajout dépense: ${e.toString()}')),
                 );
              }
            }
          },
        );
      },
    );
  }

  // Method to delete an expense using FirebaseService
  // IMPORTANT: ID is now a String
  Future<void> _deleteExpense(String id) async {
     // Optional: Confirmation Dialog
     final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Voulez-vous vraiment supprimer cette dépense ?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer')),
          ],
        ),
     );

     if (confirm == true && mounted) {
        try {
          await _firebaseService.deleteExpense(id); // Use FirebaseService method
          // If the deleted expense was the selected one, clear selection
          if (_selectedExpense != null && _selectedExpense!['id'] == id) {
             setState(() => _selectedExpense = null);
          }
          _fetchExpenses(); // Refresh the list
          if (mounted) { // Check before showing snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dépense supprimée avec succès')),
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

  // Helper to format date safely
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Date inconnue';
    // The service method already converts Timestamp to DateTime
    // If it didn't, you would check: if (timestamp is Timestamp) ...
    if (timestamp is DateTime) {
       try {
          return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(timestamp); // Use intl for formatting
       } catch (e) {
          return timestamp.toIso8601String().split('T')[0]; // Fallback format
       }
    }
    // Fallback if it's already a string (less likely with current service)
    return timestamp.toString().split('.')[0];
  }


  @override
  Widget build(BuildContext context) {
    // Ensure 'intl' is initialized for French locale if needed
    // You might need to add localization setup in main.dart for this
    // Intl.defaultLocale = 'fr_FR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Dépenses'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          Padding( // Add some padding around the button
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: _showAddExpenseDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une Dépense'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(45), // Make button taller
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? const Center(child: Text('Aucune dépense enregistrée.'))
                    // Show details if an expense is selected
                    : _selectedExpense != null
                        ? _buildExpenseDetailCard(_selectedExpense!)
                        // Show list if no expense is selected
                        : _buildExpenseList(),
          ),
        ],
      ),
    );
  }

  // Extracted widget for the list view
  Widget _buildExpenseList() {
    return ListView.builder(
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        // IMPORTANT: Get ID as String
        final String expenseId = expense['id']?.toString() ?? '';
        final String name = expense['name']?.toString() ?? 'Sans nom';
        final double amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
        // Get the DateTime object added by the service
        final DateTime? createdAt = expense['created_at_dt'];


        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                amount.toStringAsFixed(0), // Show amount without decimals
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondaryContainer),
                ),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(_formatDate(createdAt)), // Format the date nicely
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              tooltip: 'Supprimer',
              // Ensure ID is not empty before allowing delete
              onPressed: expenseId.isNotEmpty ? () => _deleteExpense(expenseId) : null,
            ),
            onTap: () {
              setState(() {
                _selectedExpense = expense; // Select this expense to show details
              });
            },
          ),
        );
      },
    );
  }

  // Extracted widget for the detail card
  Widget _buildExpenseDetailCard(Map<String, dynamic> expense) {
     // IMPORTANT: Get ID as String
     final String expenseId = expense['id']?.toString() ?? '';
     final String name = expense['name']?.toString() ?? 'Sans nom';
     final double amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
     final String description = expense['description']?.toString() ?? 'Aucune description';
     // Get the DateTime object added by the service
     final DateTime? createdAt = expense['created_at_dt'];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Make card wrap content
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Détail de la Dépense',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Row(
                    children: [
                     IconButton(
                        icon: const Icon(Icons.delete_outline),
                         color: Theme.of(context).colorScheme.error,
                         tooltip: 'Supprimer',
                         // Ensure ID is not empty
                        onPressed: expenseId.isNotEmpty ? () => _deleteExpense(expenseId) : null,
                      ),
                       IconButton(
                        icon: const Icon(Icons.close), // Changed from arrow_back
                        tooltip: 'Fermer',
                        onPressed: () {
                          setState(() {
                            _selectedExpense = null; // Go back to list view
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20, thickness: 1), // Add a divider
              const SizedBox(height: 10),
              Text( name, style: Theme.of(context).textTheme.headlineSmall ),
              const SizedBox(height: 12),
              Text( 'Montant: ${amount.toStringAsFixed(2)} DH', style: Theme.of(context).textTheme.titleMedium ),
              const SizedBox(height: 16),
              const Text( 'Description:', style: TextStyle(fontWeight: FontWeight.bold) ),
              const SizedBox(height: 4),
              Text(description.isNotEmpty ? description : 'Aucune description fournie.'),
              const SizedBox(height: 16),
              Text( 'Date: ${_formatDate(createdAt)}', style: Theme.of(context).textTheme.bodySmall ),
            ],
          ),
        ),
      ),
    );
  }
}
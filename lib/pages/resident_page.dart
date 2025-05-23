import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:syndic_app/pages/receipt_page.dart';
import 'package:syndic_app/pages/recipt_magasin_page.dart';
import 'package:syndic_app/pages/unpaid_months_page.dart';
import '../widget/add_resident_dialog.dart';
import '../widget/add_payment_dialog.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement résidents: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterResidents(String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredResidents = List.from(_residents);
      } else {
        _filteredResidents = _residents.where((resident) {
          final numero = resident['numero']?.toString() ?? '';
          return numero.toLowerCase().contains(lowerCaseQuery);
        }).toList();
      }
    });
  }

  Future<void> _showAddResidentDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddResidentDialog(),
    );

    if (result != null && mounted) {
       if (result['numero'] == null || result['type'] == null || result['monthlyDue'] == null || result['name'] == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur: Informations du résident manquantes.')),
            );
            return;
       }
      try {
        await _firebaseService.addResident(
          numero: result['numero'],
          type: result['type'],
          monthlyDue: result['monthlyDue'],
          name: result['name'],
        );
        await _loadResidents();
         if(mounted){
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

  Future<void> _showAddPaymentDialog(
    String residentId,
    String numero,
    String type,
    String name,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddPaymentDialog(
        residentId: residentId,
        residentNumero: numero,
        residentType: type,
      ),
    );

    if (result != null && mounted) {
       if (result['amount'] == null || result['monthsCovered'] == null) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Erreur: Informations du paiement manquantes.')),
           );
           return;
       }

      try {
        final Payment newPayment = await _firebaseService.addPaymentNew(
          residentId: residentId,
          amount: result['amount'],
          monthsCovered: result['monthsCovered'],
          residentName: name,
        );

        await _loadResidents();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paiement ajouté avec succès')),
          );

          if (type == 'Magasin') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReceiptPageMagasin(
                  residentNumero: numero,
                  montantParMois: newPayment.amount,
                  residentType: type,
                  paymentDate: newPayment.paymentDate,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReceiptPage(
                  residentNumero: numero,
                  montantParMois: newPayment.amount,
                  paymentDate: newPayment.paymentDate,
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

  Future<void> _deleteResident(String residentId) async {
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

     if (confirm == true && mounted) {
        try {
          await _firebaseService.deleteResident(residentId);
          await _loadResidents();
          if (mounted) {
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

  void _showUnpaidMonths(Map<String, dynamic> resident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnpaidMonthsPage(
          residentId: resident['id'],
          residentName: resident['name'],
          residentNumero: resident['numero'],
          monthlyDue: (resident['monthly_due'] as num).toDouble(),
          registrationDate: (resident['created_at'] as DateTime),
          payments: List<Map<String, dynamic>>.from(resident['payments'] ?? []),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résidents'),
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
                    : SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                             headingRowColor: MaterialStateColor.resolveWith(
                               (states) => Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3)
                             ),
                            columns: const [
                              DataColumn(label: Text('Numéro', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Nom', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Montant Mensuel', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Montant Restant', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _filteredResidents.map((resident) {
                              final String numero = resident['numero']?.toString() ?? 'N/A';
                              final String type = resident['type']?.toString() ?? 'N/A';
                              final String name = resident['name']?.toString() ?? 'N/A';
                              final double monthlyDue = (resident['monthly_due'] as num?)?.toDouble() ?? 0.0;
                              final double montantRestant = (resident['montant_restant'] as num?)?.toDouble() ?? 0.0;
                              final String residentId = resident['id']?.toString() ?? '';

                              return DataRow(
                                color: MaterialStateProperty.resolveWith<Color?>(
                                  (Set<MaterialState> states) {
                                    if (montantRestant > 0) return Colors.red.withOpacity(0.1);
                                    return null;
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
                                            ? Colors.redAccent
                                            : Colors.green,
                                      ),
                                    ),
                                    onTap: () => _showUnpaidMonths(resident),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.payment),
                                          color: Theme.of(context).colorScheme.primary,
                                          tooltip: 'Ajouter un paiement',
                                          onPressed: residentId.isNotEmpty
                                            ? () => _showAddPaymentDialog(residentId, numero, type, name)
                                            : null,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.calendar_month),
                                          color: Theme.of(context).colorScheme.secondary,
                                          tooltip: 'Voir mois non payés',
                                          onPressed: () => _showUnpaidMonths(resident),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          color: Theme.of(context).colorScheme.error,
                                          tooltip: 'Supprimer le résident',
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
        icon: const Icon(Icons.add),
        label: const Text("Ajouter Résident"),
      ),
    );
  }
}
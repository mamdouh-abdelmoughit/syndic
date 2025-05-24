// lib/pages/caisse_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import '../services/firebase_service.dart'; // Import FirebaseService

class CaissePage extends StatefulWidget {
  const CaissePage({super.key});

  @override
  State<CaissePage> createState() => _CaissePageState();
}

class _CaissePageState extends State<CaissePage> {
  late final FirebaseService _firebaseService;

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService(); // Instantiate FirebaseService
  }

  // Dialog to initialize/set the caisse balance
  Future<void> _showInitializeCaisseDialog() async {
    final TextEditingController initialAmountController =
        TextEditingController();
    final _formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Initialiser/Définir la Caisse'),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: initialAmountController,
              decoration: const InputDecoration(
                labelText: 'Montant Initial (DH)',
                hintText: 'Ex: 500.00',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un montant';
                }
                if (double.tryParse(value) == null) {
                  return 'Veuillez entrer un nombre valide';
                }
                if (double.parse(value) < 0) {
                  return 'Le montant ne peut pas être négatif';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(
                      context, double.parse(initialAmountController.text));
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    initialAmountController.dispose(); // Dispose controller

    if (result != null && mounted) {
      try {
        await _firebaseService.initializeCaisse(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caisse initialisée avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          print("Error initializing caisse: $e"); // Debug print
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur initialisation caisse: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Situation de la Caisse'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          // Center the content
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Center vertically in column
            crossAxisAlignment:
                CrossAxisAlignment.center, // Center horizontally in column
            children: [
              Text(
                'Solde Actuel:',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              // --- StreamBuilder to listen to Caisse balance ---
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _firebaseService.getCaisseBalanceStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    print(
                        "StreamBuilder Error: ${snapshot.error}"); // Debug print
                    return Text(
                      'Erreur: ${snapshot.error}',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    );
                  }

                  // Check if the document exists and has data
                  if (!snapshot.hasData ||
                      !snapshot.data!.exists ||
                      snapshot.data!.data() == null) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Caisse non initialisée.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _showInitializeCaisseDialog,
                          icon: const Icon(Icons.settings),
                          label: const Text('Initialiser la Caisse'),
                        ),
                      ],
                    );
                  }

                  // Document exists, get the balance
                  final data = snapshot.data!.data()!;
                  final double balance =
                      (data['balance'] as num?)?.toDouble() ?? 0.0;

                  return Text(
                    '${balance.toStringAsFixed(2)} DH',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: balance >= 0
                              ? Colors.green.shade700
                              : Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                  );
                },
              ),
              // --- End StreamBuilder ---
              // Optionally add spacing if you add other widgets below the balance
              const SizedBox(height: 40),
              // Add the Initialize button here as well, maybe styled differently or
              // make the StreamBuilder show it only when the document doesn't exist.
              // Let's make the StreamBuilder handle showing the init button if no data.
            ],
          ),
        ),
      ),
      // Removed FloatingActionButton to put the init button inside the body conditionally
    );
  }
}

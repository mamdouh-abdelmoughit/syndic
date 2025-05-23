import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddResidentDialog extends StatefulWidget {
  const AddResidentDialog({super.key});

  @override
  State<AddResidentDialog> createState() => _AddResidentDialogState();
}

class _AddResidentDialogState extends State<AddResidentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numeroController = TextEditingController();
  final _monthlyDueController = TextEditingController();
  String _type = 'Appart';

  @override
  void dispose() {
    _numeroController.dispose();
    _monthlyDueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un Résident'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _numeroController,
              decoration: const InputDecoration(labelText: 'Numéro'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer un numéro';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'Appart', child: Text('Appartement')),
                DropdownMenuItem(value: 'Magasin', child: Text('Magasin')),
              ],
              onChanged: (value) {
                setState(() {
                  _type = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _monthlyDueController,
              decoration: const InputDecoration(
                labelText: 'Montant Mensuel (DH)',
                hintText: 'Montant à payer chaque mois',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le montant mensuel';
                }
                return null;
              },
            ),
          ],
        ),
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
              Navigator.pop(context, {
                'numero': _numeroController.text,
                'type': _type,
                'monthlyDue': double.parse(_monthlyDueController.text),
              });
            }
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

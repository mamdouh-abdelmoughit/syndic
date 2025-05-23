import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/receipt_page.dart';

class AddPaymentDialog extends StatefulWidget {
  final String residentId;
  final String residentNumero;
  final String residentType; // Add this parameter

  const AddPaymentDialog({
    super.key,
    required this.residentId,
    required this.residentNumero,
    required this.residentType,
  });

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ajouter un Paiement - ${widget.residentNumero}'),
      content: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Montant Payé (DH)',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le montant payé';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Date de Paiement'),
                subtitle: Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
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
              // First save the payment data
              Navigator.pop(context, {
                'amount': double.parse(_amountController.text),
                'paymentDate': _selectedDate,
                'residentType': widget.residentType,
              });
              
              // Then navigate to receipt page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptPage(
                    residentNumero: widget.residentNumero,
                    montantParMois: double.parse(_amountController.text),
                    paymentDate: _selectedDate,
                  ),
                ),
              );
            }
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

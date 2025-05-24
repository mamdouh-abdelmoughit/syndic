// lib/widget/add_payment_dialog.dart (Assuming this is your path)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// Remove: import '../pages/receipt_page.dart'; // Not needed here anymore

class AddPaymentDialog extends StatefulWidget {
  final String residentId;
  final String residentNumero;
  final String residentType;
  final String? initialMonthsCovered; // To pre-fill the months covered field
  final String? initialAmount;        // To pre-fill the amount (optional)

  const AddPaymentDialog({
    super.key,
    required this.residentId,
    required this.residentNumero,
    required this.residentType,
    this.initialMonthsCovered, // Make it an optional named parameter
    this.initialAmount,        // Make it an optional named parameter
  });

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final TextEditingController _monthsCoveredController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if initial values are provided
    if (widget.initialMonthsCovered != null) {
      _monthsCoveredController.text = widget.initialMonthsCovered!;
    }
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _monthsCoveredController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000), // Sensible earliest date
      lastDate: DateTime.now(),   // Payment cannot be in the future
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
      title: Text('Ajouter Paiement: ${widget.residentNumero}'),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0), // Adjust padding
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Montant Payé (DH)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le montant.';
                  }
                  final double? amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Montant invalide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _monthsCoveredController,
                decoration: const InputDecoration(
                  labelText: 'Mois Couvert(s)',
                  hintText: 'Ex: Janvier 2024, Février 2024',
                  prefixIcon: Icon(Icons.calendar_view_month),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez spécifier le(s) mois.';
                  }
                  // Consider more robust validation if specific format (e.g., "MMMM yyyy") is required
                  // For example, using a RegExp or a parsing attempt.
                  // For now, just checking for empty.
                  return null;
                },
                maxLines: null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range),
                title: const Text('Date de Paiement Effectif'),
                subtitle: Text(
                  // Using intl for formatting the displayed date
                  DateFormat('dd/MM/yyyy', 'fr_FR').format(_selectedDate),
                ),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () => _selectDate(context),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context), // Returns null to the caller
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_card),
          label: const Text('Ajouter'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final paymentData = {
                'amount': double.parse(_amountController.text),
                // 'paymentDate' from _selectedDate is the date the payment was made/recorded by user
                // The actual Firestore timestamp will be set server-side for 'payment_date' field if using FieldValue.serverTimestamp()
                // It's good to pass this user-selected date if it represents the actual transaction date.
                'paymentDate': _selectedDate, // Renaming to avoid confusion with potential server timestamp
                'residentType': widget.residentType, // Still useful for context if needed by caller
                'monthsCovered': _monthsCoveredController.text.trim(),
              };
              Navigator.pop(context, paymentData); // Pop with the validated data
            }
          },
        ),
      ],
    );
  }
}
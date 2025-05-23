import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart'; // Import intl


class ReceiptPageMagasin extends StatefulWidget {
  final String residentNumero;
  final double montantParMois;
  final String residentType;
  final DateTime paymentDate;

  const ReceiptPageMagasin({
    super.key,
    required this.residentNumero,
    required this.montantParMois,
    required this.residentType,
    required this.paymentDate,
  });

  @override
  State<ReceiptPageMagasin> createState() => _ReceiptPageMagasinState();
}

class _ReceiptPageMagasinState extends State<ReceiptPageMagasin> {
  final _startDateController = TextEditingController(); // For rent period start
  final _endDateController = TextEditingController();   // For rent period end
  final _nameController = TextEditingController();      // For recipient's name
  bool _isGenerating = false; // To prevent double taps

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Helper to format date
  String _formatDate(DateTime date) {
    try {
      return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
    } catch (e) {
      return date.toString().split(' ')[0]; // Fallback
    }
  }

  // Generates and saves the PDF to a temporary directory
  Future<File?> _generateAndSavePdf() async {
     final pdf = pw.Document();
     final formattedPaymentDate = _formatDate(widget.paymentDate);

     // TODO: Consider validating or formatting start/end date inputs if they should be actual dates
     final String periodeDebut = _startDateController.text;
     final String periodeFin = _endDateController.text;
     final String recipientName = _nameController.text;

     pdf.addPage(
       pw.Page(
         pageFormat: PdfPageFormat.a5,
         margin: const pw.EdgeInsets.all(30), // Consistent margin
         build: (pw.Context context) {
           return pw.Column(
             crossAxisAlignment: pw.CrossAxisAlignment.start,
             children: [
               // Header
               pw.Row(
                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                 children: [
                   pw.Text('N° Local: ${widget.residentNumero}', style: const pw.TextStyle(fontSize: 14)),
                   pw.Text('Montant: ${widget.montantParMois.toStringAsFixed(2)} DH', style: const pw.TextStyle(fontSize: 14)),
                 ],
               ),
               pw.Divider(height: 20, thickness: 1),
               // Title
               pw.Center(
                 child: pw.Text('Reçu de Loyer', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
               ),
               pw.SizedBox(height: 30),
               // Details
               pw.Text('Reçu de M./Mme: $recipientName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
               pw.SizedBox(height: 15),
               pw.Text('Pour le local (${widget.residentType}) situé à: [Your Building Address/Name]'), // Add address
               pw.SizedBox(height: 15),
               pw.Text('Correspondant à la période du: $periodeDebut au $periodeFin.'),
               pw.SizedBox(height: 15),
               pw.Text('Montant du loyer payé: ${widget.montantParMois.toStringAsFixed(2)} DH.'),
               pw.SizedBox(height: 15),
               pw.Text('Date de Paiement: $formattedPaymentDate.'),
               pw.SizedBox(height: 30),
               // Legal Reserves Section
               pw.Text('Sous toutes réserves légales:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
               pw.Bullet(text: 'Ce reçu atteste uniquement du paiement pour la période indiquée.'),
               pw.Bullet(text: 'Il ne confère aucun droit supplémentaire au locataire en cas de litige.'),
               pw.Bullet(text: 'Le locataire est tenu de conserver ce reçu.'),
               // Add other relevant clauses if needed
               pw.SizedBox(height: 40),
               // Footer
               pw.Row(
                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                   children: [
                     pw.Text('Fait à [Your City Name]'), // Add City
                     pw.Text('Le: $formattedPaymentDate'), // Date receipt was generated (can be same as payment date)
                   ],
                 ),
                 pw.SizedBox(height: 40),
                  pw.Align(
                     alignment: pw.Alignment.centerRight,
                     child: pw.Text('Signature (Bailleur): _______________'),
                 )
             ],
           );
         },
       ),
     );

    try {
       final output = await getTemporaryDirectory();
       final fileName = "receipt_magasin_${widget.residentNumero}_${DateTime.now().millisecondsSinceEpoch}.pdf";
       final file = File("${output.path}/$fileName");
       await file.writeAsBytes(await pdf.save());
       print('PDF saved to: ${file.path}');
       return file;
     } catch (e) {
       print('Error saving PDF: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur sauvegarde PDF: ${e.toString()}')),
         );
       }
       return null;
     }
  }

  Future<void> _handleGenerateAndShowReceipt() async {
    if (_isGenerating) return;

    // Validation
    if (_nameController.text.isEmpty || _startDateController.text.isEmpty || _endDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir le nom et les dates de début/fin.')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    final File? file = await _generateAndSavePdf();

    if (mounted) {
      setState(() => _isGenerating = false);
    }

    if (file == null || !mounted) return;

    // Show dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reçu PDF Généré'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Fichier enregistré (temporairement):'),
              const SizedBox(height: 8),
              SelectableText(file.path, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              const Text('Partager le reçu via:'),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Partager PDF'),
              onPressed: () async { // Make async
                try {
                  final xFile = XFile(file.path);
                  // Use Share.shareXFiles
                  await Share.shareXFiles(
                    [xFile],
                    text: 'Reçu de loyer pour ${widget.residentNumero}',
                    subject: 'Reçu Loyer PDF - ${widget.residentNumero}',
                  );
                 } catch (e) {
                   print("Error sharing file: $e");
                   if(mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur partage: ${e.toString()}'))
                     );
                   }
                 }
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Intl.defaultLocale = 'fr_FR'; // Set locale if needed globally

    return Scaffold(
      appBar: AppBar(
        title: const Text('Générer Reçu de Loyer'),
         backgroundColor: Theme.of(context).colorScheme.primary,
         foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Display auto-filled information
              Card(
                 elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('N° Local: ${widget.residentNumero}', style: Theme.of(context).textTheme.titleMedium),
                       const SizedBox(height: 8),
                      Text('Type: ${widget.residentType}', style: Theme.of(context).textTheme.titleMedium),
                       const SizedBox(height: 8),
                      Text('Montant Payé: ${widget.montantParMois.toStringAsFixed(2)} DH', style: Theme.of(context).textTheme.titleMedium),
                       const SizedBox(height: 8),
                      Text('Date de Paiement: ${_formatDate(widget.paymentDate)}', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              // Manual input fields
               TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du locataire',
                  hintText: 'Entrez le nom complet',
                  border: OutlineInputBorder(),
                   prefixIcon: Icon(Icons.person_outline)
                ),
              ),
              const SizedBox(height: 16),
              // TODO: Consider using Date Pickers for these fields for better UX
              TextField(
                controller: _startDateController,
                decoration: const InputDecoration(
                  labelText: 'Période de location - Début',
                  hintText: 'Ex: 01/01/2024 ou Janvier 2024',
                  border: OutlineInputBorder(),
                   prefixIcon: Icon(Icons.date_range_outlined)
                ),
                // keyboardType: TextInputType.datetime, // If using specific format
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _endDateController,
                decoration: const InputDecoration(
                  labelText: 'Période de location - Fin',
                   hintText: 'Ex: 31/01/2024 ou Janvier 2024',
                  border: OutlineInputBorder(),
                   prefixIcon: Icon(Icons.date_range_outlined)
                ),
                 // keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _handleGenerateAndShowReceipt,
                icon: _isGenerating
                    ? Container(
                        width: 24, height: 24, padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator( color: Colors.white, strokeWidth: 3),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_isGenerating ? 'Génération...' : 'Générer et Partager le Reçu PDF'),
                 style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                   backgroundColor: Theme.of(context).colorScheme.primary,
                   foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
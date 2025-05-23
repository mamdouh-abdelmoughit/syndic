import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart'; // Import intl

class ReceiptPage extends StatefulWidget {
  final String residentNumero;
  final double montantParMois;
  final DateTime paymentDate;

  const ReceiptPage({
    super.key,
    required this.residentNumero,
    required this.montantParMois,
    required this.paymentDate,
  });

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  final _nameController = TextEditingController();
  final _monthsController = TextEditingController();
  bool _isGenerating = false; // To prevent double taps

  @override
  void dispose() {
    _nameController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  // Helper to format date
  String _formatDate(DateTime date) {
    try {
       // Example: 25/12/2023 - Adjust format as needed
      return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
    } catch (e) {
      // Fallback
      return date.toString().split(' ')[0];
    }
  }

  // Generates and saves the PDF to a temporary directory
  Future<File?> _generateAndSavePdf() async {
     final pdf = pw.Document();
     final formattedDate = _formatDate(widget.paymentDate);

     pdf.addPage(
       pw.Page(
         pageFormat: PdfPageFormat.a5,
         build: (pw.Context context) {
           return pw.Padding( // Use Padding widget for consistency
             padding: const pw.EdgeInsets.all(30), // Increased padding
             child: pw.Column(
               crossAxisAlignment: pw.CrossAxisAlignment.start,
               children: [
                 // Header Row
                 pw.Row(
                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                   children: [
                     pw.Text('N° ${widget.residentNumero}', style: const pw.TextStyle(fontSize: 14)),
                     // Format amount
                     pw.Text('B.P.DH ${widget.montantParMois.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 14)),
                   ],
                 ),
                 pw.Divider(height: 20, thickness: 1), // Add a divider
                 // Title
                 pw.Center(
                   child: pw.Text('Reçu de Paiement', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                 ),
                 pw.SizedBox(height: 30),
                 // Content
                 pw.Row(
                   children: [
                     pw.Text('Reçu de M./Mme: '),
                     pw.Expanded( // Allow name to wrap if long
                       child: pw.Text(_nameController.text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                     ),
                   ],
                 ),
                 pw.SizedBox(height: 15),
                  pw.Row(
                   children: [
                     pw.Text('La somme de: '),
                     pw.Text('${widget.montantParMois.toStringAsFixed(2)} DH',
                         style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                   ],
                 ),
                 pw.SizedBox(height: 15),
                 pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start, // Align top
                   children: [
                     pw.Text('Pour le(s) mois de: '),
                     pw.Expanded( // Allow months description to wrap
                       child: pw.Text(_monthsController.text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                     ),
                   ],
                 ),
                 pw.SizedBox(height: 40),
                 // Footer
                  pw.Row(
                   mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                   children: [
                     pw.Text('Fait à [Your City Name]'), // Add City
                     pw.Text('Le: $formattedDate'),
                   ],
                 ),
                 pw.SizedBox(height: 40),
                  pw.Align(
                     alignment: pw.Alignment.centerRight,
                     child: pw.Text('Signature: ________________'),
                 )
               ],
             ),
           );
         },
       ),
     );

    try {
       // Use temporary directory
       final output = await getTemporaryDirectory();
       final fileName = "receipt_${widget.residentNumero}_${DateTime.now().millisecondsSinceEpoch}.pdf";
       final file = File("${output.path}/$fileName");
       await file.writeAsBytes(await pdf.save());
       print('PDF saved to: ${file.path}'); // For debugging
       return file;
     } catch (e) {
       print('Error saving PDF: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error saving PDF: ${e.toString()}')),
         );
       }
       return null;
     }
  }


  Future<void> _handleGenerateAndShowReceipt() async {
    if (_isGenerating) return; // Prevent multiple simultaneous generations

    if (_nameController.text.isEmpty || _monthsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir le nom et les mois.')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    final File? file = await _generateAndSavePdf();

    if (mounted) {
      setState(() => _isGenerating = false); // Re-enable button
    }

    // If file generation failed or widget unmounted, stop here
    if (file == null || !mounted) return;

    // Show dialog with file location and share option
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
              SelectableText( // Allow copying path
                 file.path,
                 style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Text('Partager le reçu via:'),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Partager PDF'),
              onPressed: () async { // Make onPressed async
                try {
                  // 1. Create an XFile from the path
                  final xFile = XFile(file.path);

                  // 2. Use Share.shareXFiles
                  await Share.shareXFiles(
                    [xFile], // Pass list of XFiles
                    text: 'Reçu de paiement pour ${widget.residentNumero}', // More descriptive text
                    subject: 'Reçu PDF - ${widget.residentNumero}', // Subject for email
                  );
                 } catch (e) {
                   print("Error sharing file: $e");
                   if(mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not share file: ${e.toString()}'))
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
    // Ensure locale is set for intl if needed globally (usually in main.dart)
    // Intl.defaultLocale = 'fr_FR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Générer le Reçu'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          // No need for horizontal scroll here
          // scrollDirection: Axis.vertical,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally
            children: [
              // Display auto-filled information
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Numéro d\'appart/magasin: ${widget.residentNumero}', style: Theme.of(context).textTheme.titleMedium),
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
                  labelText: 'Nom du propriétaire/locataire',
                  hintText: 'Entrez le nom complet',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline)
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _monthsController,
                decoration: const InputDecoration(
                  labelText: 'Mois du paiement',
                  hintText: 'Ex: Janvier 2024, Février 2024...',
                  border: OutlineInputBorder(),
                   prefixIcon: Icon(Icons.calendar_month_outlined)
                ),
                maxLines: null, // Allow multiline input
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _handleGenerateAndShowReceipt, // Disable while generating
                icon: _isGenerating
                    ? Container( // Show progress indicator
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_isGenerating ? 'Génération...' : 'Générer et Partager le Reçu PDF'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), // Button height
                  padding: const EdgeInsets.symmetric(vertical: 15), // Vertical padding
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
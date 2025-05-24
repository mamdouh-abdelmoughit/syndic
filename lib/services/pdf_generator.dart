import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kDebugMode; // For debug prints

class PdfGenerator {
  static String _formatDate(DateTime date) {
    try {
      return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
    } catch (e) {
      if (kDebugMode) {
        print("Error formatting date in PdfGenerator: $e. Defaulting to ISO string.");
      }
      // Fallback to a more universal format if 'fr_FR' fails (e.g., during tests or if locale not init)
      return date.toIso8601String().split('T')[0];
    }
  }

  static Future<File?> generateApartmentReceipt({
    required String residentNumero,
    required String residentName,
    required double montantPaye,
    required DateTime paymentDate, // This should be the actual date the payment transaction occurred
    required String monthsDescription, // e.g., "Janvier 2024" or "Janvier 2024, Février 2024"
    String yourCityName = "VotreVille", // Default or get from config/settings
  }) async {
    final pdf = pw.Document();
    final String formattedReceiptDate = _formatDate(DateTime.now()); // Date the receipt is generated
    final String formattedPaymentActualDate = _formatDate(paymentDate); // Date of the payment itself

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(25), // Adjusted margin slightly
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    pw.Text('Appart. N°: ${residentNumero}', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('Montant Payé: ${montantPaye.toStringAsFixed(2)} DH', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('Reçu de Paiement des Frais de Syndic', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Reçu de M./Mme: ${residentName}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('La somme de: ${montantPaye.toStringAsFixed(2)} Dirhams.', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 10),
              pw.Text('Correspondant au(x) mois de: ${monthsDescription}.', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 10),
              pw.Text('Date de paiement effectif: $formattedPaymentActualDate.', style: const pw.TextStyle(fontSize: 11)),
              pw.Expanded(child: pw.SizedBox()), // Pushes content to bottom
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Fait à $yourCityName, le $formattedReceiptDate.', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Le Syndic', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Signature: _______________', style: const pw.TextStyle(fontSize: 10)),
              )
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final fileName = "recu_syndic_${residentNumero}_${monthsDescription.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());
      if (kDebugMode) {
        print('Apartment Receipt PDF saved to: ${file.path}');
      }
      return file;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving Apartment Receipt PDF: $e');
      }
      return null;
    }
  }

  static Future<File?> generateMagasinReceipt({
    required String residentNumero, // Numero du local/magasin
    required String residentName,   // Nom du locataire/propriétaire du magasin
    required String residentType,   // Should be "Magasin"
    required double montantPaye,
    required DateTime paymentDate,    // Date of the actual payment transaction
    required String monthsDescription, // e.g., "Loyer Janvier 2024" or "Janvier 2024, Février 2024"
    String yourCityName = "VotreVille",
    String buildingAddress = "Adresse de l'Immeuble/Résidence", // Add building address
  }) async {
    final pdf = pw.Document();
    final String formattedReceiptDate = _formatDate(DateTime.now()); // Date the receipt is generated
    final String formattedPaymentActualDate = _formatDate(paymentDate); // Date of the payment

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    pw.Text('Local N°: ${residentNumero} ($residentType)', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('Montant Payé: ${montantPaye.toStringAsFixed(2)} DH', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('Reçu de Loyer', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Reçu de M./Mme: ${residentName}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Pour le local commercial situé à: $buildingAddress', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 10),
              pw.Text('La somme de: ${montantPaye.toStringAsFixed(2)} Dirhams.', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 10),
              pw.Text('Correspondant au loyer pour: ${monthsDescription}.', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 10),
              pw.Text('Date de paiement effectif: $formattedPaymentActualDate.', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 15),
              pw.Text('Sous toutes réserves légales.', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
              pw.Expanded(child: pw.SizedBox()), // Pushes content to bottom
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Fait à $yourCityName, le $formattedReceiptDate.', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Le Bailleur/Gérant', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Signature: _______________', style: const pw.TextStyle(fontSize: 10)),
              )
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final fileName = "recu_loyer_${residentNumero}_${monthsDescription.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());
      if (kDebugMode) {
        print('Magasin Receipt PDF saved to: ${file.path}');
      }
      return file;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving Magasin Receipt PDF: $e');
      }
      return null;
    }
  }
}
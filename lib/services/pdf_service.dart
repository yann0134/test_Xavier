import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';

class PdfService {
  static Future<String> generateTablePdf(
    List<List<String>> data,
    List<String> headers,
    String title,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: Map.fromIterables(
                  List<int>.generate(headers.length, (i) => i),
                  List<pw.TableColumnWidth>.filled(
                    headers.length,
                    const pw.FlexColumnWidth(),
                  ),
                ),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: headers
                        .map((header) => pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                header,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  // Data rows
                  ...data.map(
                    (row) => pw.TableRow(
                      children: row
                          .map((cell) => pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text(cell),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  static Future<String> generateReceipt(Map<String, dynamic> commande) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              pw.Center(
                child: pw.Text(
                  'CaissePro Market',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('123 rue du Commerce'),
                    pw.Text('75001 Paris'),
                    pw.Text('Tel: 01 23 45 67 89'),
                  ],
                ),
              ),
              pw.Divider(),

              // Informations commande
              pw.Text(
                'RECU N° ${commande['id']}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Date: ${DateTime.now().toString().split('.')[0]}'),

              // Informations client si disponibles
              if (commande['client_nom'] != null) ...[
                pw.SizedBox(height: 10),
                pw.Text('Client: ${commande['client_nom']}'),
                if (commande['telephone'] != null)
                  pw.Text('Tel: ${commande['telephone']}'),
                if (commande['email'] != null)
                  pw.Text('Email: ${commande['email']}'),
              ],

              pw.SizedBox(height: 20),

              // Articles
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // En-tête du tableau
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text('Article',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text('Prix',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Lignes d'articles
                  ...(commande['items'] as String).split(',').map((item) {
                    final parts = item.trim().split('@');
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(parts[0].trim()),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                              '€${double.parse(parts[1].trim()).toStringAsFixed(2)}'),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '€${commande['total'].toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 40),

              // Pied de page
              pw.Center(
                child: pw.Text(
                  'Merci de votre visite !',
                  style: pw.TextStyle(
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'recu_${commande['id']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  static Future<String> generateChartPdf(
    String imageUrl,
    String title,
    String date,
  ) async {
    final pdf = pw.Document();

    // Télécharger l'image
    final response = await http.get(Uri.parse(imageUrl));
    final image = pw.MemoryImage(response.bodyBytes);

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Généré le: $date'),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Image(image, height: 400),
              ),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'chart_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  static Future<void> openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Impossible d\'ouvrir le fichier: ${result.message}');
      }
    } catch (e) {
      print('Erreur lors de l\'ouverture du fichier: $e');
      rethrow;
    }
  }
}

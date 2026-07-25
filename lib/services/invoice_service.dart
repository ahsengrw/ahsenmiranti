import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';

class InvoiceService {
  static Future<void> generateAndShare(Order order) async {
    final pdf = pw.Document();
    final date = DateTime.parse(order.createdAt);
    final formatCurrency = NumberFormat.simpleCurrency();
    final formatDate = DateFormat('MMM dd, yyyy HH:mm');

    // Add page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Meranti Beading', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Order #ORD-${order.id}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${formatDate.format(date)}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey)),
                        pw.SizedBox(height: 5),
                        pw.Text(order.customerName ?? 'Valued Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(order.customerAddress ?? 'N/A', style: pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PAYMENT METHOD:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey)),
                        pw.SizedBox(height: 5),
                        pw.Text(order.paymentMethod?.toUpperCase() ?? 'COD'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Quantity', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(order.itemsSummary ?? 'Meranti Beading Product')),
                      pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('1', textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(formatCurrency.format(order.totalAmount), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Amount', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(color: PdfColors.black),
                      pw.Text(formatCurrency.format(order.totalAmount), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Center(
                child: pw.Text('Thank you for your business!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    // Save and Share
    final directory = await getTemporaryDirectory();
    final file = File("${directory.path}/Invoice_ORD_${order.id}.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Your Invoice from Meranti Beading');
  }
}

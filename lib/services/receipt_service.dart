import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/sales_repository.dart';

class ReceiptService {
  static String _money(int minor) => 'Rs ${(minor / 100).toStringAsFixed(2)}';

  static Future<pw.Document> _buildDocument(SaleDetails details) async {
    final preferences = await SharedPreferences.getInstance();
    final businessName = preferences.getString('business_name')?.trim();
    final businessPhone = preferences.getString('business_phone')?.trim() ?? '';
    final businessEmail = preferences.getString('business_email')?.trim() ?? '';
    final businessAddress = preferences.getString('business_address')?.trim() ?? '';
    final taxNumber = preferences.getString('business_tax_number')?.trim() ?? '';
    final footer = preferences.getString('receipt_footer')?.trim() ??
        'Thank you for shopping with us!';

    final sale = details.sale;
    final pdf = pw.Document();
    final pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      300 * PdfPageFormat.mm,
      marginAll: 5 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(5 * PdfPageFormat.mm),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              businessName == null || businessName.isEmpty
                  ? 'VendraOne Store'
                  : businessName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (businessAddress.isNotEmpty)
            pw.Center(child: pw.Text(businessAddress, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
          if (businessPhone.isNotEmpty)
            pw.Center(child: pw.Text('Phone: $businessPhone', style: const pw.TextStyle(fontSize: 8))),
          if (businessEmail.isNotEmpty)
            pw.Center(child: pw.Text(businessEmail, style: const pw.TextStyle(fontSize: 8))),
          if (taxNumber.isNotEmpty)
            pw.Center(child: pw.Text('Tax No: $taxNumber', style: const pw.TextStyle(fontSize: 8))),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.Text('RECEIPT', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 5),
          pw.Text('Sale: ${sale.saleNumber}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Date: ${sale.createdAt.toLocal().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Status: ${sale.status.replaceAll('_', ' ')}', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
              bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.6),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.6),
            },
            children: [
              pw.TableRow(
                children: [
                  _cell('Item', bold: true),
                  _cell('Qty', bold: true, align: pw.TextAlign.right),
                  _cell('Total', bold: true, align: pw.TextAlign.right),
                ],
              ),
              ...details.items.map((item) => pw.TableRow(
                children: [
                  _cell(item.productName),
                  _cell(item.quantity.toString(), align: pw.TextAlign.right),
                  _cell(_money(item.totalMinor), align: pw.TextAlign.right),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 8),
          _totalRow('Subtotal', _money(sale.subtotalMinor)),
          _totalRow('Discount', '- ${_money(sale.discountMinor)}'),
          _totalRow('Tax', _money(sale.taxMinor)),
          pw.Divider(),
          _totalRow('TOTAL', _money(sale.totalMinor), bold: true),
          _totalRow('Paid', _money(sale.paidMinor)),
          _totalRow('Balance', _money(
            (sale.totalMinor - sale.paidMinor).clamp(0, sale.totalMinor),
          ), bold: true),
          if (details.payments.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('PAYMENTS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ...details.payments.map((payment) => pw.Text(
              '${payment.method.replaceAll('_', ' ')}: ${_money(payment.amountMinor)}',
              style: const pw.TextStyle(fontSize: 8),
            )),
          ],
          pw.SizedBox(height: 14),
          pw.Divider(),
          pw.Center(
            child: pw.Text(
              footer.isEmpty ? 'Thank you for shopping with us!' : footer,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text('Powered by VendraOne', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          ),
        ],
      ),
    );
    return pdf;
  }

  static pw.Widget _cell(
    String value, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Text(
        value,
        textAlign: align,
        style: pw.TextStyle(fontSize: 7.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static Future<void> printReceipt(SaleDetails details) async {
    final document = await _buildDocument(details);
    await Printing.layoutPdf(
      name: 'Receipt-${details.sale.saleNumber}.pdf',
      onLayout: (_) async => document.save(),
    );
  }

  static Future<void> shareReceipt(SaleDetails details) async {
    final document = await _buildDocument(details);
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'Receipt-${details.sale.saleNumber}.pdf',
    );
  }
}

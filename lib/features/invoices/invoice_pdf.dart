import 'dart:typed_data';

import 'package:flutter/material.dart' show BuildContext;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../app/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/account.dart';
import '../../data/models/order.dart';

//==============================================================================
// SPOCART — Invoice PDF
//------------------------------------------------------------------------------
// Builds a GST invoice for an order on-device and hands it to the platform
// share sheet (save to Files / Drive, AirDrop, email, print…).
//==============================================================================

Future<void> shareInvoicePdf(BuildContext context, Order order) async {
  final BusinessProfile? buyer =
      AppScope.of(context).session.session?.profile;
  try {
    final Uint8List bytes = await buildInvoicePdf(order, buyer: buyer);
    await Printing.sharePdf(bytes: bytes, filename: '${order.invoiceId}.pdf');
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'Could not generate the invoice. Try again.',
          tone: SnackTone.error);
    }
  }
}

Future<Uint8List> buildInvoicePdf(Order order, {BusinessProfile? buyer}) async {
  final pw.Document doc = pw.Document(
    title: 'Invoice ${order.invoiceId}',
    author: AppInfo.name,
  );

  const PdfColor red = PdfColor.fromInt(0xFFE4132B);
  const PdfColor black = PdfColor.fromInt(0xFF0B0B0C);
  const PdfColor grey = PdfColor.fromInt(0xFF7C7C86);
  const PdfColor line = PdfColor.fromInt(0xFFE2E2E5);

  pw.Widget kv(String k, String v) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(k, style: const pw.TextStyle(color: grey, fontSize: 10)),
          pw.Text(v, style: const pw.TextStyle(fontSize: 10)),
        ],
      );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: 'SPO',
                          style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: black),
                        ),
                        pw.TextSpan(
                          text: 'CART',
                          style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: red),
                        ),
                      ],
                    ),
                  ),
                  pw.Text('B2B Sports Supply',
                      style: const pw.TextStyle(color: grey, fontSize: 9)),
                  pw.Text('${AppInfo.website} · ${SupportContacts.email}',
                      style: const pw.TextStyle(color: grey, fontSize: 9)),
                  pw.Text(SupportContacts.phoneDisplay,
                      style: const pw.TextStyle(color: grey, fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('TAX INVOICE',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(order.invoiceId,
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('Order ${order.id}',
                      style: const pw.TextStyle(color: grey, fontSize: 9)),
                  pw.Text('Date ${formatDate(order.placedAt)}',
                      style: const pw.TextStyle(color: grey, fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(height: 2, color: red),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILL TO',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: grey,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Text(buyer?.businessName ?? order.address.contactName,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    if (buyer != null) pw.Text('GSTIN ${buyer.gstin}',
                        style: const pw.TextStyle(fontSize: 9)),
                    if (buyer != null) pw.Text(buyer.email,
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(formatIndianMobile(buyer?.mobile ?? order.address.mobile),
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SHIP TO',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: grey,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Text(order.address.contactName,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text(order.address.multiline,
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(formatIndianMobile(order.address.mobile),
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: black),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: line, width: 0.5),
              bottom: pw.BorderSide(color: line, width: 0.5),
            ),
            columnWidths: <int, pw.TableColumnWidth>{
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1.6),
            },
            cellAlignments: <int, pw.Alignment>{
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headers: <String>['Item', 'Qty', 'Rate', 'Amount'],
            data: <List<String>>[
              for (final OrderLine l in order.lines)
                <String>[
                  l.size == null ? l.name : '${l.name} (Size ${l.size})',
                  '${l.quantity} ${l.unit}',
                  formatInr(l.unitPrice, showSign: false),
                  formatInr(l.lineTotal, showSign: false),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 220,
                child: pw.Column(
                  children: [
                    kv('Subtotal', 'INR ${formatInr(order.subtotal, showSign: false)}'),
                    pw.SizedBox(height: 3),
                    kv('CGST 9%', 'INR ${formatInr(order.gst / 2, showSign: false)}'),
                    pw.SizedBox(height: 3),
                    kv('SGST 9%', 'INR ${formatInr(order.gst / 2, showSign: false)}'),
                    pw.SizedBox(height: 6),
                    pw.Container(height: 1, color: line),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL',
                            style: pw.TextStyle(
                                fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text('INR ${formatInr(order.total, showSign: false)}',
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: red)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            order.paid
                ? 'Payment received via ${order.paymentMethod.title}.'
                : 'Payment terms: ${order.paymentMethod.title} — due within 30 days of invoice date.',
            style: const pw.TextStyle(fontSize: 9, color: grey),
          ),
          pw.Spacer(),
          pw.Container(height: 1, color: line),
          pw.SizedBox(height: 6),
          pw.Text(
            'This is a computer-generated invoice issued by SPOCART and does not require a signature.',
            style: const pw.TextStyle(fontSize: 8, color: grey),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

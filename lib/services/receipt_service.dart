import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/mobiboss_models.dart';

class ReceiptService {
  static final _currencyFormatter = NumberFormat('#,##0.00', 'en_US');

  static String _fmt(double val) => _currencyFormatter.format(val);

  /// Generates a standard 58mm ESC/POS thermal receipt document
  static Future<pw.Document> generateThermalReceipt({
    required TransactionRecord tx,
    required Till till,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = dateFormat.format(tx.timestamp);

    final font = await PdfGoogleFonts.robotoCondensedRegular();
    final fontBold = await PdfGoogleFonts.robotoCondensedBold();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 3 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.DefaultTextStyle(
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.black),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Store Header
                pw.Text(
                  'MOBIBOSS POS',
                  style: pw.TextStyle(font: fontBold, fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Ghana Mobile Money Agent', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Agent Code: ${till.agentCode}', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Till: ${till.tillName} (${till.network.name.toUpperCase()})', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

                // Transaction Type & Status
                pw.Text(
                  _getTypeTitle(tx.type).toUpperCase(),
                  style: pw.TextStyle(font: fontBold, fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                  child: pw.Text(
                    'SUCCESSFUL / CONFIRMED',
                    style: pw.TextStyle(font: fontBold, fontSize: 7),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

                // Details Table
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date/Time:'),
                    pw.Text(formattedDate, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Customer:'),
                    pw.Text(tx.customerPhone, style: pw.TextStyle(font: fontBold)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Reference:'),
                    pw.Text(tx.reference, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

                // Amount & Fees
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Transaction Amount:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    pw.Text('GHS ${_fmt(tx.amount)}', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                  ],
                ),
                if (tx.fee > 0) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Network Fee:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('GHS ${_fmt(tx.fee)}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

                // Barcode / Footer
                pw.SizedBox(height: 4),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: tx.reference.isNotEmpty ? tx.reference : 'TX-${tx.id.substring(0, 8)}',
                  height: 22,
                  width: 40 * PdfPageFormat.mm,
                ),
                pw.SizedBox(height: 4),
                pw.Text('Thank you for transacting with us!', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('Keep this slip as proof of payment.', style: const pw.TextStyle(fontSize: 6)),
                pw.SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );

    return doc;
  }

  /// Generates a thermal End-Of-Day Shift Settlement Report
  static Future<pw.Document> generateShiftReport({
    required ShiftRecord shift,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final font = await PdfGoogleFonts.robotoCondensedRegular();
    final fontBold = await PdfGoogleFonts.robotoCondensedBold();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 3 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.DefaultTextStyle(
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.black),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'SHIFT SETTLEMENT REPORT',
                  style: pw.TextStyle(font: fontBold, fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Shift #${shift.shiftNumber}', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Start:'),
                    pw.Text(dateFormat.format(shift.startTime), style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Closed:'),
                    pw.Text(dateFormat.format(shift.endTime), style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Transactions:'),
                    pw.Text('${shift.transactionCount}', style: pw.TextStyle(font: fontBold)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Opening Drawer Cash:'),
                    pw.Text('GHS ${_fmt(shift.openingCash)}'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Inflows (+):'),
                    pw.Text('GHS ${_fmt(shift.totalCashIn)}', style: pw.TextStyle(font: fontBold)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Outflows (-):'),
                    pw.Text('GHS ${_fmt(shift.totalCashOut)}', style: pw.TextStyle(font: fontBold)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Commission:'),
                    pw.Text('GHS ${_fmt(shift.totalCommissions)}', style: pw.TextStyle(font: fontBold)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Expected Cash:'),
                    pw.Text('GHS ${_fmt(shift.expectedCash)}', style: pw.TextStyle(font: fontBold)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Counted Cash:'),
                    pw.Text('GHS ${_fmt(shift.closingCash)}', style: pw.TextStyle(font: fontBold)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Variance:'),
                    pw.Text(
                      '${shift.cashVariance >= 0 ? "+" : ""}GHS ${_fmt(shift.cashVariance)}',
                      style: pw.TextStyle(font: fontBold, fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.8),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                  child: pw.Text(
                    'AUDIT STATUS: ${shift.status}',
                    style: pw.TextStyle(font: fontBold, fontSize: 8),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(shift.aiDiagnosis, style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );

    return doc;
  }

  /// Sends receipt to Bluetooth POS Thermal printer or System print dialog
  static Future<void> printReceipt({
    required BuildContext context,
    required TransactionRecord tx,
    required Till till,
  }) async {
    final doc = await generateThermalReceipt(tx: tx, till: till);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_${tx.reference}',
    );
  }

  /// Shares receipt PDF or text to WhatsApp / SMS
  static Future<void> shareReceiptPdf({
    required TransactionRecord tx,
    required Till till,
  }) async {
    final doc = await generateThermalReceipt(tx: tx, till: till);
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Receipt_${tx.reference}.pdf');
  }

  /// Generates clean plain text receipt for instant WhatsApp/SMS sharing
  static String generateTextReceipt({
    required TransactionRecord tx,
    required Till till,
  }) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    return '''🧾 *MOBIBOSS POS RECEIPT*
━━━━━━━━━━━━━━━━━━━━
📌 *${_getTypeTitle(tx.type).toUpperCase()}* [CONFIRMED]
👤 *Customer:* ${tx.customerPhone}
💵 *Amount:* GHS ${_fmt(tx.amount)}
🔢 *Ref ID:* ${tx.reference}
🕒 *Date:* ${dateFormat.format(tx.timestamp)}
🏪 *Till:* ${till.tillName} (${till.network.name.toUpperCase()})
━━━━━━━━━━━━━━━━━━━━
Thank you for transacting with us!''';
  }

  /// Prints shift settlement report
  static Future<void> printShiftSettlementReport({
    required BuildContext context,
    required ShiftRecord shift,
  }) async {
    final doc = await generateShiftReport(shift: shift);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Shift_Settlement_${shift.shiftNumber}',
    );
  }

  /// Shares shift settlement report PDF to WhatsApp / Email / Apps
  static Future<void> shareShiftSettlementPdf({
    required ShiftRecord shift,
  }) async {
    final doc = await generateShiftReport(shift: shift);
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Shift_Settlement_${shift.shiftNumber}.pdf');
  }

  /// Generates plain text shift report for quick WhatsApp / SMS audit sharing
  static String generateShiftReportText({
    required ShiftRecord shift,
  }) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    return '''📊 *MOBIBOSS SHIFT #${shift.shiftNumber} SETTLEMENT*
━━━━━━━━━━━━━━━━━━━━
🕒 *Period:* ${dateFormat.format(shift.startTime)} → ${dateFormat.format(shift.endTime)}
🔢 *Total Transactions:* ${shift.transactionCount}
💰 *Opening Drawer Cash:* GHS ${_fmt(shift.openingCash)}
📥 *Total Inflows (+):* GHS ${_fmt(shift.totalCashIn)}
📤 *Total Outflows (-):* GHS ${_fmt(shift.totalCashOut)}
⭐ *Total Commissions:* GHS ${_fmt(shift.totalCommissions)}
━━━━━━━━━━━━━━━━━━━━
🎯 *Expected Cash:* GHS ${_fmt(shift.expectedCash)}
💵 *Counted Cash:* GHS ${_fmt(shift.closingCash)}
⚖️ *Variance:* ${shift.cashVariance >= 0 ? "+" : ""}GHS ${_fmt(shift.cashVariance)}
📌 *Status:* ${shift.status}
━━━━━━━━━━━━━━━━━━━━
_${shift.aiDiagnosis}_''';
  }

  static String _getTypeTitle(TransactionType type) {
    switch (type) {
      case TransactionType.cashIn:
        return 'Cash In (Deposit)';
      case TransactionType.cashOut:
        return 'Cash Out (Withdrawal)';
      case TransactionType.airtime:
        return 'Airtime Recharge';
      case TransactionType.dataBundle:
        return 'Data Bundle Purchase';
      case TransactionType.floatTransfer:
        return 'Float Transfer';
      case TransactionType.ecgElectricity:
        return 'ECG Power Payment';
      case TransactionType.ghanaWater:
        return 'GWCL Water Bill';
      case TransactionType.payTv:
        return 'Pay TV Subscription';
      case TransactionType.bankTransfer:
        return 'Bank Transfer';
    }
  }

  // ==========================================
  // BLUETOOTH DIRECT ESC/POS PRINTING
  // ==========================================
  static const MethodChannel _channel = MethodChannel('com.kodetech.mobiboss/ussd');

  static Future<bool> isBluetoothEnabled() async {
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isBluetoothEnabled');
      return enabled == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BluetoothPrinterInfo>> getPairedPrinters() async {
    try {
      final list = await _channel.invokeMethod<List>('getPairedBluetoothPrinters');
      if (list == null) return [];
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return BluetoothPrinterInfo(
          name: map['name'] as String? ?? 'Unknown Printer',
          address: map['address'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> printRawBytes({
    required String printerAddress,
    required List<int> bytes,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('printRawEscPos', {
        'address': printerAddress,
        'bytes': Uint8List.fromList(bytes),
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// Generates ESC/POS byte sequence for thermal receipt (58mm or 80mm)
  static List<int> buildEscPosTransactionReceipt({
    required TransactionRecord tx,
    required Till till,
    int paperWidthMm = 58,
  }) {
    final bytes = <int>[];
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = dateFormat.format(tx.timestamp);

    // Initialize printer
    bytes.addAll([0x1B, 0x40]);

    // Center alignment
    bytes.addAll([0x1B, 0x61, 0x01]);

    // Double height & width header
    bytes.addAll([0x1D, 0x21, 0x11]);
    bytes.addAll('MOBIBOSS POS\n'.codeUnits);

    // Normal text
    bytes.addAll([0x1D, 0x21, 0x00]);
    bytes.addAll('Ghana Mobile Money Agent\n'.codeUnits);
    bytes.addAll('Agent: ${till.agentCode} | Till: ${till.tillName}\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);

    // Transaction Type (Bold)
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll('${_getTypeTitle(tx.type).toUpperCase()}\n'.codeUnits);
    bytes.addAll('[SUCCESSFUL / CONFIRMED]\n'.codeUnits);
    bytes.addAll([0x1B, 0x45, 0x00]);
    bytes.addAll('--------------------------------\n'.codeUnits);

    // Left alignment for details
    bytes.addAll([0x1B, 0x61, 0x00]);
    bytes.addAll('Date: $formattedDate\n'.codeUnits);
    bytes.addAll('Customer: ${tx.customerPhone}\n'.codeUnits);
    bytes.addAll('Reference: ${tx.reference}\n'.codeUnits);
    bytes.addAll('Till: ${till.network.name.toUpperCase()}\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);

    // Amount (Double Height)
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll([0x1D, 0x21, 0x01]);
    bytes.addAll('Amount: GHS ${_fmt(tx.amount)}\n'.codeUnits);
    bytes.addAll([0x1D, 0x21, 0x00]);
    bytes.addAll([0x1B, 0x45, 0x00]);

    if (tx.fee > 0) {
      bytes.addAll('Fee: GHS ${_fmt(tx.fee)}\n'.codeUnits);
    }
    bytes.addAll('--------------------------------\n'.codeUnits);

    // Center alignment footer
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll('Thank you for your business!\n'.codeUnits);
    bytes.addAll('Powered by MobiBoss\n\n\n'.codeUnits);

    // Cut paper
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }

  /// Generates ESC/POS byte sequence for Shift Settlement report
  static List<int> buildEscPosShiftReport({
    required ShiftRecord shift,
    int paperWidthMm = 58,
  }) {
    final bytes = <int>[];
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    bytes.addAll([0x1B, 0x40]);
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll([0x1D, 0x21, 0x11]);
    bytes.addAll('MOBIBOSS POS\n'.codeUnits);
    bytes.addAll([0x1D, 0x21, 0x00]);
    bytes.addAll('SHIFT #${shift.shiftNumber} SETTLEMENT\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);

    bytes.addAll([0x1B, 0x61, 0x00]);
    bytes.addAll('Start: ${dateFormat.format(shift.startTime)}\n'.codeUnits);
    bytes.addAll('End:   ${dateFormat.format(shift.endTime)}\n'.codeUnits);
    bytes.addAll('Tx Count: ${shift.transactionCount}\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);

    bytes.addAll('Opening Cash:   GHS ${_fmt(shift.openingCash)}\n'.codeUnits);
    bytes.addAll('Total Inflow:   GHS ${_fmt(shift.totalCashIn)}\n'.codeUnits);
    bytes.addAll('Total Outflow:  GHS ${_fmt(shift.totalCashOut)}\n'.codeUnits);
    bytes.addAll('Commission:     GHS ${_fmt(shift.totalCommissions)}\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);

    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll('Expected Cash:  GHS ${_fmt(shift.expectedCash)}\n'.codeUnits);
    bytes.addAll('Counted Cash:   GHS ${_fmt(shift.closingCash)}\n'.codeUnits);
    bytes.addAll('Variance:       ${shift.cashVariance >= 0 ? "+" : ""}GHS ${_fmt(shift.cashVariance)}\n'.codeUnits);
    bytes.addAll('Status:         ${shift.status}\n'.codeUnits);
    bytes.addAll([0x1B, 0x45, 0x00]);
    bytes.addAll('--------------------------------\n'.codeUnits);

    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll('${shift.aiDiagnosis}\n\n\n'.codeUnits);
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }

  /// Generates ESC/POS byte sequence for Shift Handover report
  static List<int> buildEscPosHandoverReport({
    required ShiftHandover handover,
    int paperWidthMm = 58,
  }) {
    final bytes = <int>[];
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    bytes.addAll([0x1B, 0x40]);
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll([0x1D, 0x21, 0x11]);
    bytes.addAll('MOBIBOSS POS\n'.codeUnits);
    bytes.addAll([0x1D, 0x21, 0x00]);
    bytes.addAll('TELLER SHIFT HANDOVER\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);

    bytes.addAll([0x1B, 0x61, 0x00]);
    bytes.addAll('Outgoing: ${handover.outgoingTellerName}\n'.codeUnits);
    bytes.addAll('Incoming: ${handover.incomingTellerName}\n'.codeUnits);
    bytes.addAll('Time:     ${dateFormat.format(handover.handoverTime)}\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);

    bytes.addAll('Shift Tx Count: ${handover.shiftTransactionCount}\n'.codeUnits);
    bytes.addAll('Shift Volume:   GHS ${_fmt(handover.shiftVolume)}\n'.codeUnits);
    bytes.addAll('Shift Comm:     GHS ${_fmt(handover.shiftCommissions)}\n'.codeUnits);
    if (handover.shiftPettyCashSpent > 0) {
      bytes.addAll('Petty Cash:     GHS ${_fmt(handover.shiftPettyCashSpent)}\n'.codeUnits);
    }
    bytes.addAll('--------------------------------\n'.codeUnits);

    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll('Expected Cash:  GHS ${_fmt(handover.expectedDrawerCash)}\n'.codeUnits);
    bytes.addAll('Counted Cash:   GHS ${_fmt(handover.countedDrawerCash)}\n'.codeUnits);
    bytes.addAll('Variance:       ${handover.cashVariance >= 0 ? "+" : ""}GHS ${_fmt(handover.cashVariance)}\n'.codeUnits);
    bytes.addAll([0x1B, 0x45, 0x00]);

    if (handover.notes.isNotEmpty) {
      bytes.addAll('Notes: ${handover.notes}\n'.codeUnits);
    }
    bytes.addAll('--------------------------------\n'.codeUnits);

    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll('Sign Outgoing: ________________\n'.codeUnits);
    bytes.addAll('Sign Incoming: ________________\n\n\n'.codeUnits);
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }
}

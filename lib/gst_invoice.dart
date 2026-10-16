
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GSTInvoicePreview extends StatelessWidget {
  final String businessName;
  final String address;
  final String phone;
  final String gstin;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String customerName;
  final String customerAddress;
  final String customerGstin;
  final List<Map<String, dynamic>> items;
  final double receivedAmount;
  final double gstRate;
  final bool isInterstate;

  const GSTInvoicePreview({
    super.key,
    this.businessName = 'PR BUSINESS',
    this.address = '',
    this.phone = '',
    this.gstin = '',
    this.invoiceNumber = 'INV-0001',
    required this.invoiceDate,
    required this.customerName,
    this.customerAddress = '',
    this.customerGstin = '',
    required this.items,
    this.receivedAmount = 0,
    this.gstRate = 18,
    this.isInterstate = false,
  });

  String money(double value) =>
      NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 2,
      ).format(value);

  double itemValue(Map<String, dynamic> item, String key) {
    final value = item[key];
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final taxable = items.fold<double>(
      0,
      (sum, item) {
        final quantity = itemValue(item, 'quantity');
        final rate = itemValue(item, 'rate');
        return sum + quantity * rate;
      },
    );

    final gst = taxable * gstRate / 100;
    final total = taxable + gst;
    final balance = (total - receivedAmount)
        .clamp(0.0, total)
        .toDouble();

    final baseStyle = Theme.of(context).textTheme.bodyMedium;

    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 11,
              )),
          const SizedBox(height: 3),
          Text(value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );

    Widget amountRow(String label, double amount,
        {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                )),
          ),
          Text(money(amount),
              style: TextStyle(
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text('GST Invoice Preview'),
        backgroundColor: const Color(0xFF142B4A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Card(
              elevation: 2,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF142B4A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            businessName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (address.isNotEmpty)
                            Text(address,
                                style: const TextStyle(
                                    color: Colors.white70)),
                          if (phone.isNotEmpty)
                            Text('Phone: $phone',
                                style: const TextStyle(
                                    color: Colors.white70)),
                          if (gstin.isNotEmpty)
                            Text('GSTIN: $gstin',
                                style: const TextStyle(
                                    color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Center(
                      child: Text(
                        'TAX INVOICE',
                        style: TextStyle(
                          color: Color(0xFF142B4A),
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: detail(
                              'INVOICE NUMBER', invoiceNumber),
                        ),
                        Expanded(
                          child: detail(
                            'INVOICE DATE',
                            DateFormat('dd MMM yyyy')
                                .format(invoiceDate),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 25),
                    const Text(
                      'BILL TO',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (customerAddress.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(customerAddress),
                      ),
                    if (customerGstin.isNotEmpty)
                      Text('GSTIN: $customerGstin'),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF0F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text('DESCRIPTION',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                )),
                          ),
                          SizedBox(
                            width: 35,
                            child: Text('QTY',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                )),
                          ),
                          SizedBox(
                            width: 76,
                            child: Text('RATE',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                )),
                          ),
                          SizedBox(
                            width: 84,
                            child: Text('AMOUNT',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                )),
                          ),
                        ],
                      ),
                    ),
                    ...items.map((item) {
                      final quantity =
                          itemValue(item, 'quantity');
                      final rate = itemValue(item, 'rate');
                      final lineTotal = quantity * rate;
                      final description =
                          '${item['description'] ?? item['name'] ?? ''}';

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 7),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(description,
                                  style: baseStyle),
                            ),
                            SizedBox(
                              width: 35,
                              child: Text(
                                quantity.toStringAsFixed(
                                  quantity == quantity.roundToDouble()
                                      ? 0
                                      : 2,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(
                              width: 76,
                              child: Text(money(rate),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 11)),
                            ),
                            SizedBox(
                              width: 84,
                              child: Text(money(lineTotal),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 25),
                    amountRow('Taxable Amount', taxable),
                    if (isInterstate)
                      amountRow('IGST (${gstRate.toStringAsFixed(1)}%)', gst)
                    else ...[
                      amountRow(
                          'CGST (${(gstRate / 2).toStringAsFixed(1)}%)',
                          gst / 2),
                      amountRow(
                          'SGST (${(gstRate / 2).toStringAsFixed(1)}%)',
                          gst / 2),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF0F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          amountRow('GRAND TOTAL', total, bold: true),
                          amountRow('Amount Received',
                              receivedAmount),
                          const Divider(),
                          amountRow('BALANCE DUE', balance,
                              bold: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Center(
                      child: Text(
                        'Thank you for your business!',
                        style: TextStyle(
                          color: Color(0xFF142B4A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Center(
                      child: Text(
                        'PR Business',
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

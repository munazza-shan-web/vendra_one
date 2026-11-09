
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';
import '../local/database/database_provider.dart';

class SaleCartItem {
  const SaleCartItem({
    required this.productId,
    required this.quantity,
  });

  final String productId;
  final int quantity;
}

class SalePaymentInput {
  const SalePaymentInput({
    required this.amountMinor,
    required this.method,
    this.reference,
  });

  final int amountMinor;
  final String method;
  final String? reference;
}

class RefundLineInput {
  const RefundLineInput({
    required this.saleItemId,
    required this.quantity,
  });

  final String saleItemId;
  final int quantity;
}

class SaleDetails {
  const SaleDetails({
    required this.sale,
    required this.items,
    required this.payments,
  });

  final Sale sale;
  final List<SaleItem> items;
  final List<Payment> payments;
}

class SalesRepository {
  SalesRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  static const _paymentMethods = {
    'cash',
    'card',
    'bank_transfer',
    'other',
  };

  // CREATE SALE

  Future<String> createSale({
    required List<SaleCartItem> items,
    required List<SalePaymentInput> payments,
    String? customerId,
    int discountMinor = 0,
    int taxRateBasisPoints = 0,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Add at least one product to the sale.');
    }

    if (discountMinor < 0 || taxRateBasisPoints < 0) {
      throw ArgumentError('Discount and tax cannot be negative.');
    }

    if (items.map((e) => e.productId).toSet().length != items.length) {
      throw ArgumentError('Each product must appear only once in the cart.');
    }

    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Product quantities must be greater than zero.');
      }
    }

    for (final payment in payments) {
      if (payment.amountMinor <= 0) {
        throw ArgumentError('Payment amounts must be greater than zero.');
      }
      _validatePaymentMethod(payment.method);
    }

    return _database.transaction(() async {
      if (customerId != null) {
        final customer = await (_database.select(_database.customers)
              ..where(
                (row) =>
                    row.id.equals(customerId) &
                    row.isActive.equals(true),
              ))
            .getSingleOrNull();

        if (customer == null) {
          throw StateError('Customer not found or inactive.');
        }
      }

      final products = <Product>[];
      var subtotalMinor = 0;

      for (final cartItem in items) {
        final product = await (_database.select(_database.products)
              ..where(
                (row) =>
                    row.id.equals(cartItem.productId) &
                    row.isActive.equals(true),
              ))
            .getSingleOrNull();

        if (product == null) {
          throw StateError('A product in the cart is unavailable.');
        }

        if (product.stockQuantity < cartItem.quantity) {
          throw StateError(
            'Insufficient stock for ${product.name}. '
            'Available: ${product.stockQuantity}.',
          );
        }

        products.add(product);
        subtotalMinor += product.sellingPriceMinor * cartItem.quantity;
      }

      if (discountMinor > subtotalMinor) {
        throw ArgumentError('Discount cannot exceed the subtotal.');
      }

      final taxableAmount = subtotalMinor - discountMinor;
      final taxMinor =
          (taxableAmount * taxRateBasisPoints + 5000) ~/ 10000;
      final totalMinor = taxableAmount + taxMinor;

      final paidMinor = payments.fold<int>(
        0,
        (total, payment) => total + payment.amountMinor,
      );

      if (paidMinor > totalMinor) {
        throw ArgumentError('Payment cannot exceed the sale total.');
      }

      if (paidMinor < totalMinor && customerId == null) {
        throw ArgumentError(
          'A customer is required for unpaid or partially paid sales.',
        );
      }

      final paymentStatus = paidMinor == 0
          ? 'unpaid'
          : paidMinor < totalMinor
              ? 'partially_paid'
              : 'paid';

      final saleId = _uuid.v4();
      final now = DateTime.now();

      final saleNumber =
          'VND-${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}-'
          '${_uuid.v4().substring(0, 6).toUpperCase()}';

      final lineSubtotals = List<int>.generate(
        items.length,
        (index) =>
            products[index].sellingPriceMinor * items[index].quantity,
      );

      final discountAllocations = _allocate(
        discountMinor,
        lineSubtotals,
      );

      final taxableLines = List<int>.generate(
        items.length,
        (index) => lineSubtotals[index] - discountAllocations[index],
      );

      final taxAllocations = _allocate(taxMinor, taxableLines);

      await _database.into(_database.sales).insert(
        SalesCompanion.insert(
          id: saleId,
          saleNumber: saleNumber,
          customerId: Value(customerId),
          subtotalMinor: subtotalMinor,
          discountMinor: Value(discountMinor),
          taxRateBasisPoints: Value(taxRateBasisPoints),
          taxMinor: Value(taxMinor),
          totalMinor: totalMinor,
          paidMinor: Value(paidMinor),
          status: const Value('completed'),
          paymentStatus: Value(paymentStatus),
          notes: Value(_clean(notes)),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      for (var index = 0; index < items.length; index++) {
        final product = products[index];
        final cartItem = items[index];
        final lineTotal = taxableLines[index] + taxAllocations[index];

        await _database.into(_database.saleItems).insert(
          SaleItemsCompanion.insert(
            id: _uuid.v4(),
            saleId: saleId,
            productId: product.id,
            productName: product.name,
            sku: Value(product.sku),
            quantity: cartItem.quantity,
            unitPriceMinor: product.sellingPriceMinor,
            unitCostMinor: Value(product.costPriceMinor),
            subtotalMinor: lineSubtotals[index],
            discountMinor: Value(discountAllocations[index]),
            taxMinor: Value(taxAllocations[index]),
            totalMinor: lineTotal,
            createdAt: Value(now),
          ),
        );

        final updated = await (_database.update(_database.products)
              ..where(
                (row) =>
                    row.id.equals(product.id) &
                    row.isActive.equals(true) &
                    row.stockQuantity.isBiggerOrEqual(Variable<int>(cartItem.quantity)),
              ))
            .write(
          ProductsCompanion(
            stockQuantity: Value(
              product.stockQuantity - cartItem.quantity,
            ),
            updatedAt: Value(now),
          ),
        );

        if (updated != 1) {
          throw StateError(
            'Stock changed while processing ${product.name}. '
            'Please try checkout again.',
          );
        }
      }

      for (final payment in payments) {
        await _database.into(_database.payments).insert(
          PaymentsCompanion.insert(
            id: _uuid.v4(),
            saleId: saleId,
            amountMinor: payment.amountMinor,
            method: payment.method,
            reference: Value(_clean(payment.reference)),
            createdAt: Value(now),
          ),
        );
      }

      return saleId;
    });
  }

  // SALES HISTORY

  Future<List<Sale>> getAllSales() {
    return (_database.select(_database.sales)
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .get();
  }

  Stream<List<Sale>> watchSales() {
    return (_database.select(_database.sales)
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .watch();
  }

  Future<SaleDetails?> getSaleDetails(String saleId) async {
    final sale = await (_database.select(_database.sales)
          ..where((row) => row.id.equals(saleId)))
        .getSingleOrNull();

    if (sale == null) return null;

    final items = await (_database.select(_database.saleItems)
          ..where((row) => row.saleId.equals(saleId)))
        .get();

    final payments = await (_database.select(_database.payments)
          ..where((row) => row.saleId.equals(saleId))
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .get();

    return SaleDetails(
      sale: sale,
      items: items,
      payments: payments,
    );
  }

  // GET QUANTITIES ALREADY RETURNED FOR EACH SALE ITEM

  Future<Map<String, int>> getReturnedQuantities(String saleId) async {
    final refunds = await (_database.select(_database.refunds)
          ..where((row) => row.saleId.equals(saleId)))
        .get();

    if (refunds.isEmpty) {
      return {};
    }

    final refundIds = refunds.map((refund) => refund.id).toList();

    final refundItems = await (_database.select(_database.refundItems)
          ..where((row) => row.refundId.isIn(refundIds)))
        .get();

    final returnedQuantities = <String, int>{};

    for (final item in refundItems) {
      returnedQuantities.update(
        item.saleItemId,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }

    return returnedQuantities;
  }

  // OUTSTANDING BALANCE AFTER RETURNS

  Future<int> getOutstandingForSale(Sale sale) async {
    if (sale.status == 'cancelled') return 0;

    final refunds = await (_database.select(_database.refunds)
          ..where((row) => row.saleId.equals(sale.id)))
        .get();

    final refundIds = refunds.map((row) => row.id).toList();

    var returnedGoodsValue = 0;

    if (refundIds.isNotEmpty) {
      final refundItems = await (_database.select(_database.refundItems)
            ..where((row) => row.refundId.isIn(refundIds)))
          .get();

      returnedGoodsValue = refundItems.fold<int>(
        0,
        (total, item) => total + item.amountMinor,
      );
    }

    final cashRefunded = refunds.fold<int>(
      0,
      (total, refund) => total + refund.amountMinor,
    );

    final balance = sale.totalMinor -
        sale.paidMinor -
        returnedGoodsValue +
        cashRefunded;

    return balance > 0 ? balance : 0;
  }

  // COLLECT PAYMENT

  Future<void> recordPayment({
    required String saleId,
    required int amountMinor,
    required String method,
    String? reference,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('Payment must be greater than zero.');
    }

    _validatePaymentMethod(method);

    await _database.transaction(() async {
      final sale = await (_database.select(_database.sales)
            ..where((row) => row.id.equals(saleId)))
          .getSingleOrNull();

      if (sale == null || sale.status == 'cancelled') {
        throw StateError('Sale not found or cancelled.');
      }

      final outstanding = await getOutstandingForSale(sale);

      if (outstanding <= 0) {
        throw StateError('This sale has no outstanding balance.');
      }

      if (amountMinor > outstanding) {
        throw ArgumentError('Payment exceeds the outstanding balance.');
      }

      final now = DateTime.now();

      await _database.into(_database.payments).insert(
        PaymentsCompanion.insert(
          id: _uuid.v4(),
          saleId: saleId,
          amountMinor: amountMinor,
          method: method,
          reference: Value(_clean(reference)),
          createdAt: Value(now),
        ),
      );

      final newPaid = sale.paidMinor + amountMinor;
      final newOutstanding = outstanding - amountMinor;

      await (_database.update(_database.sales)
            ..where((row) => row.id.equals(saleId)))
          .write(
        SalesCompanion(
          paidMinor: Value(newPaid),
          paymentStatus: Value(
            newOutstanding == 0 ? 'paid' : 'partially_paid',
          ),
          updatedAt: Value(now),
        ),
      );
    });
  }

  // CANCEL UNPAID SALE

  Future<void> cancelSale({
    required String saleId,
    String? reason,
  }) async {
    await _database.transaction(() async {
      final sale = await (_database.select(_database.sales)
            ..where((row) => row.id.equals(saleId)))
          .getSingleOrNull();

      if (sale == null || sale.status != 'completed') {
        throw StateError('This sale cannot be cancelled.');
      }

      if (sale.paidMinor > 0) {
        throw StateError(
          'This sale has received payment. Refund the payment first.',
        );
      }

      final items = await (_database.select(_database.saleItems)
            ..where((row) => row.saleId.equals(saleId)))
          .get();

      final now = DateTime.now();

      for (final item in items) {
        final product = await (_database.select(_database.products)
              ..where((row) => row.id.equals(item.productId)))
            .getSingleOrNull();

        if (product != null) {
          await (_database.update(_database.products)
                ..where((row) => row.id.equals(item.productId)))
              .write(
            ProductsCompanion(
              stockQuantity: Value(product.stockQuantity + item.quantity),
              updatedAt: Value(now),
            ),
          );
        }
      }

      await (_database.update(_database.sales)
            ..where((row) => row.id.equals(saleId)))
          .write(
        SalesCompanion(
          status: const Value('cancelled'),
          notes: Value(_clean(reason) ?? sale.notes),
          updatedAt: Value(now),
        ),
      );
    });
  }

  // RETURN ITEMS AND REFUND WHAT WAS ACTUALLY PAID

  Future<String> refundSale({
    required String saleId,
    required List<RefundLineInput> items,
    required String refundMethod,
    String? reason,
    String? reference,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Select at least one item to return.');
    }

    _validatePaymentMethod(refundMethod);

    if (items.map((row) => row.saleItemId).toSet().length != items.length) {
      throw ArgumentError('Each sale item must appear only once.');
    }

    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Return quantities must be greater than zero.');
      }
    }

    return _database.transaction(() async {
      final sale = await (_database.select(_database.sales)
            ..where((row) => row.id.equals(saleId)))
          .getSingleOrNull();

      if (sale == null || sale.status == 'cancelled') {
        throw StateError('Sale not found or cancelled.');
      }

      if (sale.status == 'refunded') {
        throw StateError('All items in this sale have already been returned.');
      }

      final previousRefunds = await (_database.select(_database.refunds)
            ..where((row) => row.saleId.equals(saleId)))
          .get();

      final previousRefundIds = previousRefunds.map((row) => row.id).toList();

      final previousCashRefunded = previousRefunds.fold<int>(
        0,
        (total, row) => total + row.amountMinor,
      );

      final previousRefundItems = previousRefundIds.isEmpty
          ? <RefundItem>[]
          : await (_database.select(_database.refundItems)
                ..where((row) => row.refundId.isIn(previousRefundIds)))
              .get();

      var returnedGoodsValue = 0;
      final selectedItems = <SaleItem>[];
      final quantities = <int>[];
      final lineAmounts = <int>[];

      for (final input in items) {
        final saleItem = await (_database.select(_database.saleItems)
              ..where(
                (row) =>
                    row.id.equals(input.saleItemId) &
                    row.saleId.equals(saleId),
              ))
            .getSingleOrNull();

        if (saleItem == null) {
          throw StateError('A selected sale item was not found.');
        }

        final alreadyReturned = previousRefundItems
            .where((row) => row.saleItemId == saleItem.id)
            .fold<int>(0, (total, row) => total + row.quantity);

        final available = saleItem.quantity - alreadyReturned;

        if (input.quantity > available) {
          throw StateError(
            'Return quantity exceeds the remaining quantity '
            'for ${saleItem.productName}.',
          );
        }

        final beforeAmount =
            (saleItem.totalMinor * alreadyReturned) ~/ saleItem.quantity;

        final afterAmount =
            (saleItem.totalMinor * (alreadyReturned + input.quantity)) ~/
                saleItem.quantity;

        final lineAmount = afterAmount - beforeAmount;

        selectedItems.add(saleItem);
        quantities.add(input.quantity);
        lineAmounts.add(lineAmount);
        returnedGoodsValue += lineAmount;
      }

      if (returnedGoodsValue <= 0) {
        throw ArgumentError('Return value must be greater than zero.');
      }

      final refundableAvailable = sale.paidMinor - previousCashRefunded;
      final cashRefund = returnedGoodsValue < refundableAvailable
          ? returnedGoodsValue
          : refundableAvailable;

      final refundId = _uuid.v4();
      final now = DateTime.now();

      await _database.into(_database.refunds).insert(
        RefundsCompanion.insert(
          id: refundId,
          saleId: saleId,
          amountMinor: cashRefund,
          reason: Value(_clean(reason)),
          createdAt: Value(now),
        ),
      );

      for (var index = 0; index < selectedItems.length; index++) {
        final saleItem = selectedItems[index];
        final quantity = quantities[index];
        final lineAmount = lineAmounts[index];

        await _database.into(_database.refundItems).insert(
          RefundItemsCompanion.insert(
            id: _uuid.v4(),
            refundId: refundId,
            saleItemId: saleItem.id,
            quantity: quantity,
            amountMinor: lineAmount,
            createdAt: Value(now),
          ),
        );

        final product = await (_database.select(_database.products)
              ..where((row) => row.id.equals(saleItem.productId)))
            .getSingleOrNull();

        if (product != null) {
          await (_database.update(_database.products)
                ..where((row) => row.id.equals(product.id)))
              .write(
            ProductsCompanion(
              stockQuantity: Value(product.stockQuantity + quantity),
              updatedAt: Value(now),
            ),
          );
        }
      }

      // A refund payment is recorded only when money is actually returned.
      if (cashRefund > 0) {
        await _database.into(_database.refundPayments).insert(
          RefundPaymentsCompanion.insert(
            id: _uuid.v4(),
            refundId: refundId,
            amountMinor: cashRefund,
            method: refundMethod,
            reference: Value(_clean(reference)),
            createdAt: Value(now),
          ),
        );
      }

      final allSaleItems = await (_database.select(_database.saleItems)
            ..where((row) => row.saleId.equals(saleId)))
          .get();

      final allRefundIds = [...previousRefundIds, refundId];

      final allReturnedItems = await (_database.select(_database.refundItems)
            ..where((row) => row.refundId.isIn(allRefundIds)))
          .get();

      final fullyReturned = allSaleItems.every((saleItem) {
        final returned = allReturnedItems
            .where((row) => row.saleItemId == saleItem.id)
            .fold<int>(0, (total, row) => total + row.quantity);

        return returned >= saleItem.quantity;
      });

      final allReturnedGoodsValue =
          previousRefundItems.fold<int>(
            0,
            (total, row) => total + row.amountMinor,
          ) +
          returnedGoodsValue;

      final totalCashRefunded = previousCashRefunded + cashRefund;

      final balance = sale.totalMinor -
          sale.paidMinor -
          allReturnedGoodsValue +
          totalCashRefunded;

      await (_database.update(_database.sales)
            ..where((row) => row.id.equals(saleId)))
          .write(
        SalesCompanion(
          status: Value(fullyReturned ? 'refunded' : 'partially_refunded'),
          paymentStatus: Value(
            balance <= 0
                ? 'paid'
                : sale.paidMinor == totalCashRefunded
                    ? 'unpaid'
                    : 'partially_paid',
          ),
          updatedAt: Value(now),
        ),
      );

      return refundId;
    });
  }

  // HELPERS

  List<int> _allocate(int amount, List<int> weights) {
    if (weights.isEmpty) return [];

    final totalWeight = weights.fold<int>(
      0,
      (total, value) => total + value,
    );

    if (amount == 0 || totalWeight == 0) {
      return List<int>.filled(weights.length, 0);
    }

    var allocated = 0;
    final result = <int>[];

    for (var index = 0; index < weights.length; index++) {
      final value = index == weights.length - 1
          ? amount - allocated
          : (amount * weights[index]) ~/ totalWeight;

      result.add(value);
      allocated += value;
    }

    return result;
  }

  void _validatePaymentMethod(String method) {
    if (!_paymentMethods.contains(method)) {
      throw ArgumentError('Unsupported payment method: $method');
    }
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(appDatabaseProvider));
});

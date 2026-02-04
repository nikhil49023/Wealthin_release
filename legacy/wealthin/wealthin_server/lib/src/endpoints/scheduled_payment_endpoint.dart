import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

/// ScheduledPaymentEndpoint: Manage recurring payments and reminders
class ScheduledPaymentEndpoint extends Endpoint {
  
  /// Get all scheduled payments for a user
  Future<List<ScheduledPayment>> getScheduledPayments(Session session, int userId) async {
    return await ScheduledPayment.db.find(
      session,
      where: (p) => p.userProfileId.equals(userId),
      orderBy: (p) => p.nextDueDate,
    );
  }

  /// Get active scheduled payments only
  Future<List<ScheduledPayment>> getActivePayments(Session session, int userId) async {
    return await ScheduledPayment.db.find(
      session,
      where: (p) => p.userProfileId.equals(userId) & p.isActive.equals(true),
      orderBy: (p) => p.nextDueDate,
    );
  }

  /// Get upcoming payments (due within next 7 days)
  Future<List<ScheduledPayment>> getUpcomingPayments(Session session, int userId) async {
    final payments = await getActivePayments(session, userId);
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    
    return payments.where((p) => 
      p.nextDueDate.isAfter(now) && p.nextDueDate.isBefore(weekFromNow)
    ).toList();
  }

  /// Get overdue payments
  Future<List<ScheduledPayment>> getOverduePayments(Session session, int userId) async {
    final payments = await getActivePayments(session, userId);
    final now = DateTime.now();
    
    return payments.where((p) => p.nextDueDate.isBefore(now)).toList();
  }

  /// Create a new scheduled payment
  Future<ScheduledPayment> createPayment(Session session, ScheduledPayment payment) async {
    payment.createdAt = DateTime.now();
    payment.isActive = true;
    return await ScheduledPayment.db.insertRow(session, payment);
  }

  /// Update a scheduled payment
  Future<ScheduledPayment> updatePayment(Session session, ScheduledPayment payment) async {
    payment.updatedAt = DateTime.now();
    return await ScheduledPayment.db.updateRow(session, payment);
  }

  /// Mark a payment as paid and calculate next due date
  Future<ScheduledPayment> markAsPaid(Session session, int paymentId) async {
    final payment = await ScheduledPayment.db.findById(session, paymentId);
    if (payment == null) {
      throw Exception('Payment not found');
    }
    
    payment.lastPaidDate = DateTime.now();
    
    // Calculate next due date based on frequency
    switch (payment.frequency) {
      case 'daily':
        payment.nextDueDate = payment.nextDueDate.add(const Duration(days: 1));
        break;
      case 'weekly':
        payment.nextDueDate = payment.nextDueDate.add(const Duration(days: 7));
        break;
      case 'monthly':
        payment.nextDueDate = DateTime(
          payment.nextDueDate.year,
          payment.nextDueDate.month + 1,
          payment.nextDueDate.day,
        );
        break;
      case 'yearly':
        payment.nextDueDate = DateTime(
          payment.nextDueDate.year + 1,
          payment.nextDueDate.month,
          payment.nextDueDate.day,
        );
        break;
    }
    
    payment.updatedAt = DateTime.now();
    return await ScheduledPayment.db.updateRow(session, payment);
  }

  /// Toggle payment active status
  Future<ScheduledPayment> toggleActive(Session session, int paymentId) async {
    final payment = await ScheduledPayment.db.findById(session, paymentId);
    if (payment == null) {
      throw Exception('Payment not found');
    }
    
    payment.isActive = !payment.isActive;
    payment.updatedAt = DateTime.now();
    return await ScheduledPayment.db.updateRow(session, payment);
  }

  /// Delete a scheduled payment
  Future<bool> deletePayment(Session session, int paymentId) async {
    final deleted = await ScheduledPayment.db.deleteWhere(
      session,
      where: (p) => p.id.equals(paymentId),
    );
    return deleted.isNotEmpty;
  }

  /// Get payment summary for a user
  Future<Map<String, dynamic>> getPaymentSummary(Session session, int userId) async {
    final payments = await getActivePayments(session, userId);
    final overdue = await getOverduePayments(session, userId);
    final upcoming = await getUpcomingPayments(session, userId);
    
    double monthlyTotal = 0;
    for (final p in payments) {
      switch (p.frequency) {
        case 'daily':
          monthlyTotal += p.amount * 30;
          break;
        case 'weekly':
          monthlyTotal += p.amount * 4;
          break;
        case 'monthly':
          monthlyTotal += p.amount;
          break;
        case 'yearly':
          monthlyTotal += p.amount / 12;
          break;
      }
    }
    
    return {
      'total_active': payments.length,
      'overdue_count': overdue.length,
      'upcoming_count': upcoming.length,
      'monthly_total': monthlyTotal.round(),
    };
  }
}

import 'package:serverpod/serverpod.dart' hide Transaction;
import '../generated/protocol.dart';

class TransactionEndpoint extends Endpoint {
  
  Future<List<Transaction>> getTransactions(Session session, {String? type}) async {
    return [];
  }

  Future<void> addTransaction(Session session, Transaction transaction) async {
    // Mock add
    session.log('Adding transaction: ${transaction.description}');
  }
}

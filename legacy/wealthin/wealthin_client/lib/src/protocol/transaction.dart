/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

abstract class Transaction implements _i1.SerializableModel {
  Transaction._({
    this.id,
    required this.amount,
    required this.description,
    required this.date,
    required this.type,
    required this.category,
    required this.userProfileId,
  });

  factory Transaction({
    int? id,
    required double amount,
    required String description,
    required DateTime date,
    required String type,
    required String category,
    required int userProfileId,
  }) = _TransactionImpl;

  factory Transaction.fromJson(Map<String, dynamic> jsonSerialization) {
    return Transaction(
      id: jsonSerialization['id'] as int?,
      amount: (jsonSerialization['amount'] as num).toDouble(),
      description: jsonSerialization['description'] as String,
      date: _i1.DateTimeJsonExtension.fromJson(jsonSerialization['date']),
      type: jsonSerialization['type'] as String,
      category: jsonSerialization['category'] as String,
      userProfileId: jsonSerialization['userProfileId'] as int,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  double amount;

  String description;

  DateTime date;

  String type;

  String category;

  int userProfileId;

  /// Returns a shallow copy of this [Transaction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Transaction copyWith({
    int? id,
    double? amount,
    String? description,
    DateTime? date,
    String? type,
    String? category,
    int? userProfileId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Transaction',
      if (id != null) 'id': id,
      'amount': amount,
      'description': description,
      'date': date.toJson(),
      'type': type,
      'category': category,
      'userProfileId': userProfileId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TransactionImpl extends Transaction {
  _TransactionImpl({
    int? id,
    required double amount,
    required String description,
    required DateTime date,
    required String type,
    required String category,
    required int userProfileId,
  }) : super._(
         id: id,
         amount: amount,
         description: description,
         date: date,
         type: type,
         category: category,
         userProfileId: userProfileId,
       );

  /// Returns a shallow copy of this [Transaction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Transaction copyWith({
    Object? id = _Undefined,
    double? amount,
    String? description,
    DateTime? date,
    String? type,
    String? category,
    int? userProfileId,
  }) {
    return Transaction(
      id: id is int? ? id : this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      userProfileId: userProfileId ?? this.userProfileId,
    );
  }
}

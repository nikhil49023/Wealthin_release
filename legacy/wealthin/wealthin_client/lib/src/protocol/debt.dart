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

/// Debt model for tracking loans, EMIs, and credit
abstract class Debt implements _i1.SerializableModel {
  Debt._({
    this.id,
    required this.userProfileId,
    required this.name,
    required this.debtType,
    required this.principal,
    required this.interestRate,
    this.emi,
    required this.startDate,
    this.tenureMonths,
    required this.remainingAmount,
    this.nextDueDate,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.notes,
  });

  factory Debt({
    int? id,
    required int userProfileId,
    required String name,
    required String debtType,
    required double principal,
    required double interestRate,
    double? emi,
    required DateTime startDate,
    int? tenureMonths,
    required double remainingAmount,
    DateTime? nextDueDate,
    required String status,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? notes,
  }) = _DebtImpl;

  factory Debt.fromJson(Map<String, dynamic> jsonSerialization) {
    return Debt(
      id: jsonSerialization['id'] as int?,
      userProfileId: jsonSerialization['userProfileId'] as int,
      name: jsonSerialization['name'] as String,
      debtType: jsonSerialization['debtType'] as String,
      principal: (jsonSerialization['principal'] as num).toDouble(),
      interestRate: (jsonSerialization['interestRate'] as num).toDouble(),
      emi: (jsonSerialization['emi'] as num?)?.toDouble(),
      startDate: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['startDate'],
      ),
      tenureMonths: jsonSerialization['tenureMonths'] as int?,
      remainingAmount: (jsonSerialization['remainingAmount'] as num).toDouble(),
      nextDueDate: jsonSerialization['nextDueDate'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['nextDueDate'],
            ),
      status: jsonSerialization['status'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
      notes: jsonSerialization['notes'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userProfileId;

  String name;

  String debtType;

  double principal;

  double interestRate;

  double? emi;

  DateTime startDate;

  int? tenureMonths;

  double remainingAmount;

  DateTime? nextDueDate;

  String status;

  DateTime createdAt;

  DateTime? updatedAt;

  String? notes;

  /// Returns a shallow copy of this [Debt]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Debt copyWith({
    int? id,
    int? userProfileId,
    String? name,
    String? debtType,
    double? principal,
    double? interestRate,
    double? emi,
    DateTime? startDate,
    int? tenureMonths,
    double? remainingAmount,
    DateTime? nextDueDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Debt',
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      'name': name,
      'debtType': debtType,
      'principal': principal,
      'interestRate': interestRate,
      if (emi != null) 'emi': emi,
      'startDate': startDate.toJson(),
      if (tenureMonths != null) 'tenureMonths': tenureMonths,
      'remainingAmount': remainingAmount,
      if (nextDueDate != null) 'nextDueDate': nextDueDate?.toJson(),
      'status': status,
      'createdAt': createdAt.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      if (notes != null) 'notes': notes,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DebtImpl extends Debt {
  _DebtImpl({
    int? id,
    required int userProfileId,
    required String name,
    required String debtType,
    required double principal,
    required double interestRate,
    double? emi,
    required DateTime startDate,
    int? tenureMonths,
    required double remainingAmount,
    DateTime? nextDueDate,
    required String status,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? notes,
  }) : super._(
         id: id,
         userProfileId: userProfileId,
         name: name,
         debtType: debtType,
         principal: principal,
         interestRate: interestRate,
         emi: emi,
         startDate: startDate,
         tenureMonths: tenureMonths,
         remainingAmount: remainingAmount,
         nextDueDate: nextDueDate,
         status: status,
         createdAt: createdAt,
         updatedAt: updatedAt,
         notes: notes,
       );

  /// Returns a shallow copy of this [Debt]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Debt copyWith({
    Object? id = _Undefined,
    int? userProfileId,
    String? name,
    String? debtType,
    double? principal,
    double? interestRate,
    Object? emi = _Undefined,
    DateTime? startDate,
    Object? tenureMonths = _Undefined,
    double? remainingAmount,
    Object? nextDueDate = _Undefined,
    String? status,
    DateTime? createdAt,
    Object? updatedAt = _Undefined,
    Object? notes = _Undefined,
  }) {
    return Debt(
      id: id is int? ? id : this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      name: name ?? this.name,
      debtType: debtType ?? this.debtType,
      principal: principal ?? this.principal,
      interestRate: interestRate ?? this.interestRate,
      emi: emi is double? ? emi : this.emi,
      startDate: startDate ?? this.startDate,
      tenureMonths: tenureMonths is int? ? tenureMonths : this.tenureMonths,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      nextDueDate: nextDueDate is DateTime? ? nextDueDate : this.nextDueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt is DateTime? ? updatedAt : this.updatedAt,
      notes: notes is String? ? notes : this.notes,
    );
  }
}

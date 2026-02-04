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

/// ScheduledPayment model for recurring payment reminders
abstract class ScheduledPayment implements _i1.SerializableModel {
  ScheduledPayment._({
    this.id,
    required this.userProfileId,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.nextDueDate,
    required this.autoTrack,
    this.category,
    required this.isActive,
    this.lastPaidDate,
    required this.createdAt,
    this.updatedAt,
    this.notes,
  });

  factory ScheduledPayment({
    int? id,
    required int userProfileId,
    required String name,
    required double amount,
    required String frequency,
    required DateTime nextDueDate,
    required bool autoTrack,
    String? category,
    required bool isActive,
    DateTime? lastPaidDate,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? notes,
  }) = _ScheduledPaymentImpl;

  factory ScheduledPayment.fromJson(Map<String, dynamic> jsonSerialization) {
    return ScheduledPayment(
      id: jsonSerialization['id'] as int?,
      userProfileId: jsonSerialization['userProfileId'] as int,
      name: jsonSerialization['name'] as String,
      amount: (jsonSerialization['amount'] as num).toDouble(),
      frequency: jsonSerialization['frequency'] as String,
      nextDueDate: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['nextDueDate'],
      ),
      autoTrack: jsonSerialization['autoTrack'] as bool,
      category: jsonSerialization['category'] as String?,
      isActive: jsonSerialization['isActive'] as bool,
      lastPaidDate: jsonSerialization['lastPaidDate'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastPaidDate'],
            ),
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

  double amount;

  String frequency;

  DateTime nextDueDate;

  bool autoTrack;

  String? category;

  bool isActive;

  DateTime? lastPaidDate;

  DateTime createdAt;

  DateTime? updatedAt;

  String? notes;

  /// Returns a shallow copy of this [ScheduledPayment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ScheduledPayment copyWith({
    int? id,
    int? userProfileId,
    String? name,
    double? amount,
    String? frequency,
    DateTime? nextDueDate,
    bool? autoTrack,
    String? category,
    bool? isActive,
    DateTime? lastPaidDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ScheduledPayment',
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      'name': name,
      'amount': amount,
      'frequency': frequency,
      'nextDueDate': nextDueDate.toJson(),
      'autoTrack': autoTrack,
      if (category != null) 'category': category,
      'isActive': isActive,
      if (lastPaidDate != null) 'lastPaidDate': lastPaidDate?.toJson(),
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

class _ScheduledPaymentImpl extends ScheduledPayment {
  _ScheduledPaymentImpl({
    int? id,
    required int userProfileId,
    required String name,
    required double amount,
    required String frequency,
    required DateTime nextDueDate,
    required bool autoTrack,
    String? category,
    required bool isActive,
    DateTime? lastPaidDate,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? notes,
  }) : super._(
         id: id,
         userProfileId: userProfileId,
         name: name,
         amount: amount,
         frequency: frequency,
         nextDueDate: nextDueDate,
         autoTrack: autoTrack,
         category: category,
         isActive: isActive,
         lastPaidDate: lastPaidDate,
         createdAt: createdAt,
         updatedAt: updatedAt,
         notes: notes,
       );

  /// Returns a shallow copy of this [ScheduledPayment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ScheduledPayment copyWith({
    Object? id = _Undefined,
    int? userProfileId,
    String? name,
    double? amount,
    String? frequency,
    DateTime? nextDueDate,
    bool? autoTrack,
    Object? category = _Undefined,
    bool? isActive,
    Object? lastPaidDate = _Undefined,
    DateTime? createdAt,
    Object? updatedAt = _Undefined,
    Object? notes = _Undefined,
  }) {
    return ScheduledPayment(
      id: id is int? ? id : this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      autoTrack: autoTrack ?? this.autoTrack,
      category: category is String? ? category : this.category,
      isActive: isActive ?? this.isActive,
      lastPaidDate: lastPaidDate is DateTime?
          ? lastPaidDate
          : this.lastPaidDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt is DateTime? ? updatedAt : this.updatedAt,
      notes: notes is String? ? notes : this.notes,
    );
  }
}

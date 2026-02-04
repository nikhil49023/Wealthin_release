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

abstract class Budget implements _i1.SerializableModel {
  Budget._({
    this.id,
    required this.name,
    this.category,
    required this.amount,
    this.limit,
    this.period,
    required this.spent,
    required this.icon,
    required this.userProfileId,
    this.createdAt,
    this.updatedAt,
  });

  factory Budget({
    int? id,
    required String name,
    String? category,
    required double amount,
    double? limit,
    String? period,
    required double spent,
    required String icon,
    required int userProfileId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BudgetImpl;

  factory Budget.fromJson(Map<String, dynamic> jsonSerialization) {
    return Budget(
      id: jsonSerialization['id'] as int?,
      name: jsonSerialization['name'] as String,
      category: jsonSerialization['category'] as String?,
      amount: (jsonSerialization['amount'] as num).toDouble(),
      limit: (jsonSerialization['limit'] as num?)?.toDouble(),
      period: jsonSerialization['period'] as String?,
      spent: (jsonSerialization['spent'] as num).toDouble(),
      icon: jsonSerialization['icon'] as String,
      userProfileId: jsonSerialization['userProfileId'] as int,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String name;

  String? category;

  double amount;

  double? limit;

  String? period;

  double spent;

  String icon;

  int userProfileId;

  DateTime? createdAt;

  DateTime? updatedAt;

  /// Returns a shallow copy of this [Budget]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Budget copyWith({
    int? id,
    String? name,
    String? category,
    double? amount,
    double? limit,
    String? period,
    double? spent,
    String? icon,
    int? userProfileId,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Budget',
      if (id != null) 'id': id,
      'name': name,
      if (category != null) 'category': category,
      'amount': amount,
      if (limit != null) 'limit': limit,
      if (period != null) 'period': period,
      'spent': spent,
      'icon': icon,
      'userProfileId': userProfileId,
      if (createdAt != null) 'createdAt': createdAt?.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BudgetImpl extends Budget {
  _BudgetImpl({
    int? id,
    required String name,
    String? category,
    required double amount,
    double? limit,
    String? period,
    required double spent,
    required String icon,
    required int userProfileId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         name: name,
         category: category,
         amount: amount,
         limit: limit,
         period: period,
         spent: spent,
         icon: icon,
         userProfileId: userProfileId,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [Budget]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Budget copyWith({
    Object? id = _Undefined,
    String? name,
    Object? category = _Undefined,
    double? amount,
    Object? limit = _Undefined,
    Object? period = _Undefined,
    double? spent,
    String? icon,
    int? userProfileId,
    Object? createdAt = _Undefined,
    Object? updatedAt = _Undefined,
  }) {
    return Budget(
      id: id is int? ? id : this.id,
      name: name ?? this.name,
      category: category is String? ? category : this.category,
      amount: amount ?? this.amount,
      limit: limit is double? ? limit : this.limit,
      period: period is String? ? period : this.period,
      spent: spent ?? this.spent,
      icon: icon ?? this.icon,
      userProfileId: userProfileId ?? this.userProfileId,
      createdAt: createdAt is DateTime? ? createdAt : this.createdAt,
      updatedAt: updatedAt is DateTime? ? updatedAt : this.updatedAt,
    );
  }
}

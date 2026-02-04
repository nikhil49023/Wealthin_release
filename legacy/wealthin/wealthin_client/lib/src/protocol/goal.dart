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

abstract class Goal implements _i1.SerializableModel {
  Goal._({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    this.status,
    required this.isDefault,
    required this.userProfileId,
    this.createdAt,
    this.updatedAt,
    this.notes,
  });

  factory Goal({
    int? id,
    required String name,
    required double targetAmount,
    required double currentAmount,
    DateTime? deadline,
    String? status,
    required bool isDefault,
    required int userProfileId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) = _GoalImpl;

  factory Goal.fromJson(Map<String, dynamic> jsonSerialization) {
    return Goal(
      id: jsonSerialization['id'] as int?,
      name: jsonSerialization['name'] as String,
      targetAmount: (jsonSerialization['targetAmount'] as num).toDouble(),
      currentAmount: (jsonSerialization['currentAmount'] as num).toDouble(),
      deadline: jsonSerialization['deadline'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['deadline']),
      status: jsonSerialization['status'] as String?,
      isDefault: jsonSerialization['isDefault'] as bool,
      userProfileId: jsonSerialization['userProfileId'] as int,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
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

  String name;

  double targetAmount;

  double currentAmount;

  DateTime? deadline;

  String? status;

  bool isDefault;

  int userProfileId;

  DateTime? createdAt;

  DateTime? updatedAt;

  String? notes;

  /// Returns a shallow copy of this [Goal]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Goal copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    String? status,
    bool? isDefault,
    int? userProfileId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Goal',
      if (id != null) 'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      if (deadline != null) 'deadline': deadline?.toJson(),
      if (status != null) 'status': status,
      'isDefault': isDefault,
      'userProfileId': userProfileId,
      if (createdAt != null) 'createdAt': createdAt?.toJson(),
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

class _GoalImpl extends Goal {
  _GoalImpl({
    int? id,
    required String name,
    required double targetAmount,
    required double currentAmount,
    DateTime? deadline,
    String? status,
    required bool isDefault,
    required int userProfileId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) : super._(
         id: id,
         name: name,
         targetAmount: targetAmount,
         currentAmount: currentAmount,
         deadline: deadline,
         status: status,
         isDefault: isDefault,
         userProfileId: userProfileId,
         createdAt: createdAt,
         updatedAt: updatedAt,
         notes: notes,
       );

  /// Returns a shallow copy of this [Goal]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Goal copyWith({
    Object? id = _Undefined,
    String? name,
    double? targetAmount,
    double? currentAmount,
    Object? deadline = _Undefined,
    Object? status = _Undefined,
    bool? isDefault,
    int? userProfileId,
    Object? createdAt = _Undefined,
    Object? updatedAt = _Undefined,
    Object? notes = _Undefined,
  }) {
    return Goal(
      id: id is int? ? id : this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline is DateTime? ? deadline : this.deadline,
      status: status is String? ? status : this.status,
      isDefault: isDefault ?? this.isDefault,
      userProfileId: userProfileId ?? this.userProfileId,
      createdAt: createdAt is DateTime? ? createdAt : this.createdAt,
      updatedAt: updatedAt is DateTime? ? updatedAt : this.updatedAt,
      notes: notes is String? ? notes : this.notes,
    );
  }
}

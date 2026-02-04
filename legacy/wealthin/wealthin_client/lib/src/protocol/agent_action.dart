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

/// AgentAction model for logging AI-triggered actions
abstract class AgentAction implements _i1.SerializableModel {
  AgentAction._({
    this.id,
    required this.userProfileId,
    required this.actionType,
    required this.parameters,
    required this.status,
    this.resultMessage,
    required this.createdAt,
    this.executedAt,
    this.relatedEntityId,
    this.relatedEntityType,
  });

  factory AgentAction({
    int? id,
    required int userProfileId,
    required String actionType,
    required String parameters,
    required String status,
    String? resultMessage,
    required DateTime createdAt,
    DateTime? executedAt,
    int? relatedEntityId,
    String? relatedEntityType,
  }) = _AgentActionImpl;

  factory AgentAction.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentAction(
      id: jsonSerialization['id'] as int?,
      userProfileId: jsonSerialization['userProfileId'] as int,
      actionType: jsonSerialization['actionType'] as String,
      parameters: jsonSerialization['parameters'] as String,
      status: jsonSerialization['status'] as String,
      resultMessage: jsonSerialization['resultMessage'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      executedAt: jsonSerialization['executedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['executedAt']),
      relatedEntityId: jsonSerialization['relatedEntityId'] as int?,
      relatedEntityType: jsonSerialization['relatedEntityType'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userProfileId;

  String actionType;

  String parameters;

  String status;

  String? resultMessage;

  DateTime createdAt;

  DateTime? executedAt;

  int? relatedEntityId;

  String? relatedEntityType;

  /// Returns a shallow copy of this [AgentAction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentAction copyWith({
    int? id,
    int? userProfileId,
    String? actionType,
    String? parameters,
    String? status,
    String? resultMessage,
    DateTime? createdAt,
    DateTime? executedAt,
    int? relatedEntityId,
    String? relatedEntityType,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentAction',
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      'actionType': actionType,
      'parameters': parameters,
      'status': status,
      if (resultMessage != null) 'resultMessage': resultMessage,
      'createdAt': createdAt.toJson(),
      if (executedAt != null) 'executedAt': executedAt?.toJson(),
      if (relatedEntityId != null) 'relatedEntityId': relatedEntityId,
      if (relatedEntityType != null) 'relatedEntityType': relatedEntityType,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentActionImpl extends AgentAction {
  _AgentActionImpl({
    int? id,
    required int userProfileId,
    required String actionType,
    required String parameters,
    required String status,
    String? resultMessage,
    required DateTime createdAt,
    DateTime? executedAt,
    int? relatedEntityId,
    String? relatedEntityType,
  }) : super._(
         id: id,
         userProfileId: userProfileId,
         actionType: actionType,
         parameters: parameters,
         status: status,
         resultMessage: resultMessage,
         createdAt: createdAt,
         executedAt: executedAt,
         relatedEntityId: relatedEntityId,
         relatedEntityType: relatedEntityType,
       );

  /// Returns a shallow copy of this [AgentAction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentAction copyWith({
    Object? id = _Undefined,
    int? userProfileId,
    String? actionType,
    String? parameters,
    String? status,
    Object? resultMessage = _Undefined,
    DateTime? createdAt,
    Object? executedAt = _Undefined,
    Object? relatedEntityId = _Undefined,
    Object? relatedEntityType = _Undefined,
  }) {
    return AgentAction(
      id: id is int? ? id : this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      actionType: actionType ?? this.actionType,
      parameters: parameters ?? this.parameters,
      status: status ?? this.status,
      resultMessage: resultMessage is String?
          ? resultMessage
          : this.resultMessage,
      createdAt: createdAt ?? this.createdAt,
      executedAt: executedAt is DateTime? ? executedAt : this.executedAt,
      relatedEntityId: relatedEntityId is int?
          ? relatedEntityId
          : this.relatedEntityId,
      relatedEntityType: relatedEntityType is String?
          ? relatedEntityType
          : this.relatedEntityType,
    );
  }
}

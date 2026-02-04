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
import 'package:wealthin_client/src/protocol/protocol.dart' as _i2;

abstract class UserProfile implements _i1.SerializableModel {
  UserProfile._({
    this.id,
    required this.uid,
    required this.credits,
    this.completedGoals,
  });

  factory UserProfile({
    int? id,
    required String uid,
    required int credits,
    List<String>? completedGoals,
  }) = _UserProfileImpl;

  factory UserProfile.fromJson(Map<String, dynamic> jsonSerialization) {
    return UserProfile(
      id: jsonSerialization['id'] as int?,
      uid: jsonSerialization['uid'] as String,
      credits: jsonSerialization['credits'] as int,
      completedGoals: jsonSerialization['completedGoals'] == null
          ? null
          : _i2.Protocol().deserialize<List<String>>(
              jsonSerialization['completedGoals'],
            ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String uid;

  int credits;

  List<String>? completedGoals;

  /// Returns a shallow copy of this [UserProfile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  UserProfile copyWith({
    int? id,
    String? uid,
    int? credits,
    List<String>? completedGoals,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserProfile',
      if (id != null) 'id': id,
      'uid': uid,
      'credits': credits,
      if (completedGoals != null) 'completedGoals': completedGoals?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserProfileImpl extends UserProfile {
  _UserProfileImpl({
    int? id,
    required String uid,
    required int credits,
    List<String>? completedGoals,
  }) : super._(
         id: id,
         uid: uid,
         credits: credits,
         completedGoals: completedGoals,
       );

  /// Returns a shallow copy of this [UserProfile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  UserProfile copyWith({
    Object? id = _Undefined,
    String? uid,
    int? credits,
    Object? completedGoals = _Undefined,
  }) {
    return UserProfile(
      id: id is int? ? id : this.id,
      uid: uid ?? this.uid,
      credits: credits ?? this.credits,
      completedGoals: completedGoals is List<String>?
          ? completedGoals
          : this.completedGoals?.map((e0) => e0).toList(),
    );
  }
}

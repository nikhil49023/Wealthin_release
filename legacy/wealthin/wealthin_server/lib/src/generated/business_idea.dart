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
import 'package:serverpod/serverpod.dart' as _i1;
import 'package:wealthin_server/src/generated/protocol.dart' as _i2;

abstract class BusinessIdea
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  BusinessIdea._({
    required this.title,
    required this.score,
    required this.strengths,
    required this.weaknesses,
    required this.suggestions,
    required this.estimatedInvestment,
    required this.timeToBreakeven,
  });

  factory BusinessIdea({
    required String title,
    required int score,
    required List<String> strengths,
    required List<String> weaknesses,
    required List<String> suggestions,
    required String estimatedInvestment,
    required String timeToBreakeven,
  }) = _BusinessIdeaImpl;

  factory BusinessIdea.fromJson(Map<String, dynamic> jsonSerialization) {
    return BusinessIdea(
      title: jsonSerialization['title'] as String,
      score: jsonSerialization['score'] as int,
      strengths: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['strengths'],
      ),
      weaknesses: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['weaknesses'],
      ),
      suggestions: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['suggestions'],
      ),
      estimatedInvestment: jsonSerialization['estimatedInvestment'] as String,
      timeToBreakeven: jsonSerialization['timeToBreakeven'] as String,
    );
  }

  String title;

  int score;

  List<String> strengths;

  List<String> weaknesses;

  List<String> suggestions;

  String estimatedInvestment;

  String timeToBreakeven;

  /// Returns a shallow copy of this [BusinessIdea]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  BusinessIdea copyWith({
    String? title,
    int? score,
    List<String>? strengths,
    List<String>? weaknesses,
    List<String>? suggestions,
    String? estimatedInvestment,
    String? timeToBreakeven,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BusinessIdea',
      'title': title,
      'score': score,
      'strengths': strengths.toJson(),
      'weaknesses': weaknesses.toJson(),
      'suggestions': suggestions.toJson(),
      'estimatedInvestment': estimatedInvestment,
      'timeToBreakeven': timeToBreakeven,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BusinessIdea',
      'title': title,
      'score': score,
      'strengths': strengths.toJson(),
      'weaknesses': weaknesses.toJson(),
      'suggestions': suggestions.toJson(),
      'estimatedInvestment': estimatedInvestment,
      'timeToBreakeven': timeToBreakeven,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _BusinessIdeaImpl extends BusinessIdea {
  _BusinessIdeaImpl({
    required String title,
    required int score,
    required List<String> strengths,
    required List<String> weaknesses,
    required List<String> suggestions,
    required String estimatedInvestment,
    required String timeToBreakeven,
  }) : super._(
         title: title,
         score: score,
         strengths: strengths,
         weaknesses: weaknesses,
         suggestions: suggestions,
         estimatedInvestment: estimatedInvestment,
         timeToBreakeven: timeToBreakeven,
       );

  /// Returns a shallow copy of this [BusinessIdea]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  BusinessIdea copyWith({
    String? title,
    int? score,
    List<String>? strengths,
    List<String>? weaknesses,
    List<String>? suggestions,
    String? estimatedInvestment,
    String? timeToBreakeven,
  }) {
    return BusinessIdea(
      title: title ?? this.title,
      score: score ?? this.score,
      strengths: strengths ?? this.strengths.map((e0) => e0).toList(),
      weaknesses: weaknesses ?? this.weaknesses.map((e0) => e0).toList(),
      suggestions: suggestions ?? this.suggestions.map((e0) => e0).toList(),
      estimatedInvestment: estimatedInvestment ?? this.estimatedInvestment,
      timeToBreakeven: timeToBreakeven ?? this.timeToBreakeven,
    );
  }
}

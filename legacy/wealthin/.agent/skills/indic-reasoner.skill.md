---
name: indic-reasoner
description: Sarvam AI integration for Indic language and cultural context
---

# Sarvam Indic Reasoner Skill

This skill provides integration with Sarvam AI for culturally and linguistically relevant financial advice for Indian users.

## Purpose

- Handle queries in regional Indian languages (Hindi, Telugu, Tamil, etc.)
- Provide culturally-aware financial advice
- Understand Indian business models (Kirana stores, local manufacturing)
- Support regional market nuances

## Trigger Conditions

This skill activates when:
- Query contains regional language text
- Query mentions local business types (Kirana, dhaba, etc.)
- Query asks about regional schemes or markets
- User profile indicates regional language preference

## Integration Architecture

```
User Query → Language Detection → [Regional?] → Sarvam API
                                      ↓
                                  [English] → Standard LLM
```

## API Integration (TODO)

```dart
// Future implementation
class SarvamService {
  Future<String> indicChat(String query, String language) async {
    // Call Sarvam API for Indic language processing
    // Return culturally-aware response
  }
  
  Future<String> translateToIndic(String english, String targetLang) async {
    // Translate response to regional language
  }
}
```

## Language Support

Priority languages:
1. Hindi (हिंदी)
2. Telugu (తెలుగు)
3. Tamil (தமிழ்)
4. Kannada (ಕನ್ನಡ)
5. Marathi (मराठी)

## Cultural Context Examples

- "Kirana store" → Small retail/grocery shop
- "Mandap" → Event venue/catering business
- "Dhaba" → Highway restaurant
- "Tiffin service" → Meal delivery service

## Implementation Status

- [ ] Language detection service
- [ ] Sarvam API integration
- [ ] Regional scheme database
- [ ] Translation pipeline

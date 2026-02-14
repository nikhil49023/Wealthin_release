"""
Brainstorm Intent Router
Routes user queries to appropriate handlers: templates, GPT-4o, or specialized services
Goal: Reduce GPT-4o usage by 60% through smart routing
"""

from enum import Enum
from typing import Dict, Any, Tuple
import re


class BrainstormIntent(Enum):
    """Intent categories for brainstorm queries"""
    CREATE_PLAN = "create_plan"           # "Create business plan" → Use template
    EVALUATE_IDEA = "evaluate"            # "Is X good?" → Use GPT-4o
    FIND_FUNDING = "funding"              # "Get loan" → Static KB
    DRAFT_DOCUMENT = "draft_document"     # "Draft DPR" → Template
    FIND_LOCAL_MSME = "local_msme"        # "Find suppliers" → Gov API
    CALCULATE_METRICS = "metrics"         # "Calculate DSCR" → Local math
    GENERAL_QUESTION = "general"          # Fallback → GPT-4o


class BrainstormRouter:
    """Routes brainstorm queries to appropriate handlers"""

    def __init__(self):
        # Intent detection keywords with weights
        self.intent_patterns = {
            BrainstormIntent.CREATE_PLAN: {
                'keywords': [
                    'business plan', 'create plan', 'business model',
                    'business proposal', 'plan outline', 'planning',
                    'business structure', 'company plan'
                ],
                'weight': 0.8,
                'use_template': True
            },
            BrainstormIntent.FIND_FUNDING: {
                'keywords': [
                    'loan', 'funding', 'finance', 'mudra', 'pmegp',
                    'stand-up india', 'credit', 'capital', 'investment',
                    'grant', 'subsidy', 'scheme', 'government scheme'
                ],
                'weight': 0.9,
                'use_template': True
            },
            BrainstormIntent.DRAFT_DOCUMENT: {
                'keywords': [
                    'dpr', 'detailed project report', 'draft', 'document',
                    'proposal', 'application', 'form', 'prepare document'
                ],
                'weight': 0.85,
                'use_template': True
            },
            BrainstormIntent.FIND_LOCAL_MSME: {
                'keywords': [
                    'find msme', 'local business', 'suppliers', 'vendors',
                    'manufacturers', 'registered msme', 'udyam',
                    'business directory', 'local suppliers'
                ],
                'weight': 0.9,
                'use_template': False,  # Use Gov API
                'use_gov_api': True
            },
            BrainstormIntent.CALCULATE_METRICS: {
                'keywords': [
                    'calculate', 'dscr', 'roi', 'payback', 'break-even',
                    'revenue', 'profit', 'margin', 'financial metric',
                    'ratio', 'analysis'
                ],
                'weight': 0.85,
                'use_template': False,  # Use local calculation
                'use_calculator': True
            },
            BrainstormIntent.EVALUATE_IDEA: {
                'keywords': [
                    'evaluate', 'is this good', 'feasibility', 'viable',
                    'worth it', 'should i', 'opinion', 'advice',
                    'pros and cons', 'risk', 'challenge', 'competition'
                ],
                'weight': 0.7,
                'use_template': False,  # Use GPT-4o
                'use_llm': True
            }
        }

    def classify_intent(self, query: str) -> Tuple[BrainstormIntent, Dict[str, Any]]:
        """
        Classify query intent using keyword scoring

        Args:
            query: User's brainstorm query

        Returns:
            Tuple of (Intent, Config dict with routing metadata)
        """
        query_lower = query.lower()

        # Score each intent
        scores = {}
        for intent, config in self.intent_patterns.items():
            score = 0.0
            matched_keywords = []

            for keyword in config['keywords']:
                if keyword in query_lower:
                    score += config['weight']
                    matched_keywords.append(keyword)

            scores[intent] = {
                'score': score,
                'matched_keywords': matched_keywords,
                'config': config
            }

        # Get highest scoring intent
        if not any(s['score'] > 0 for s in scores.values()):
            # No matches - default to GPT-4o for general questions
            return (BrainstormIntent.GENERAL_QUESTION, {
                'use_llm': True,
                'use_template': False,
                'confidence': 0.0
            })

        best_intent = max(scores.items(), key=lambda x: x[1]['score'])[0]
        best_score_data = scores[best_intent]

        # Calculate confidence (normalize score)
        max_possible_score = len(best_score_data['matched_keywords']) * \
                           self.intent_patterns[best_intent]['weight']
        confidence = min(best_score_data['score'] / max(max_possible_score, 1.0), 1.0)

        # Build config
        config = {
            'confidence': confidence,
            'matched_keywords': best_score_data['matched_keywords'],
            **self.intent_patterns[best_intent]
        }

        return (best_intent, config)

    def extract_entities(self, query: str, intent: BrainstormIntent) -> Dict[str, Any]:
        """Extract relevant entities from query based on intent"""
        entities = {}

        # Extract business type
        business_type_patterns = [
            r'(?:open|start|create|launch)\s+(?:a\s+)?(\w+\s+business)',
            r'(\w+\s+shop|store|cafe|restaurant)',
        ]
        for pattern in business_type_patterns:
            match = re.search(pattern, query, re.IGNORECASE)
            if match:
                entities['business_type'] = match.group(1)
                break

        # Extract location
        location_patterns = [
            r'in\s+(\w+(?:\s+\w+)?)',
            r'at\s+(\w+(?:\s+\w+)?)',
        ]
        for pattern in location_patterns:
            match = re.search(pattern, query, re.IGNORECASE)
            if match:
                location = match.group(1)
                # Filter out common words
                if location.lower() not in ['the', 'my', 'this', 'that']:
                    entities['location'] = location
                    break

        # Extract capital/amount
        amount_patterns = [
            r'(?:₹|rs\.?|inr)\s*([\d,]+(?:\.\d+)?)\s*(?:lakh|crore|thousand)?',
            r'([\d,]+(?:\.\d+)?)\s*(?:lakh|crore|rupees)',
        ]
        for pattern in amount_patterns:
            match = re.search(pattern, query, re.IGNORECASE)
            if match:
                entities['capital'] = match.group(1)
                break

        return entities


# Singleton instance
brainstorm_router = BrainstormRouter()

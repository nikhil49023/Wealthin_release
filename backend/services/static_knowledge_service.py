"""
Static Knowledge Service
Loads tax rules, GST rates, etc. from local JSON files.
No network calls, instant responses.
"""

import json
from pathlib import Path
from typing import Dict, List, Optional
import logging

logger = logging.getLogger(__name__)

class StaticKnowledgeService:
    """
    Manages offline financial knowledge (tax slabs, deductions, formulas).
    Loaded from local JSON files at startup.
    """
    
    def __init__(self, knowledge_dir: str = "data/knowledge_base"):
        # Make path relative to backend root if possible
        base_dir = Path(__file__).parent.parent
        self.knowledge_dir = base_dir / knowledge_dir
        self.data = {}
        self.load_all()
    
    def load_all(self):
        """Load all JSON files into memory"""
        if not self.knowledge_dir.exists():
            logger.warning(f"Knowledge directory not found: {self.knowledge_dir}")
            return
        
        for json_file in self.knowledge_dir.glob("*.json"):
            try:
                with open(json_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    self.data[json_file.stem] = data
                    logger.info(f"Loaded {json_file.name}")
            except Exception as e:
                logger.error(f"Error loading {json_file}: {e}")
    
    def search(self, query: str, category: str = None) -> List[Dict]:
        """
        Simple keyword search in static knowledge.
        
        Args:
            query: Search terms
            category: Optional category filter (income_tax, gst, etc.)
            
        Returns:
            List of matching items
        """
        query_lower = query.lower()
        query_words = set(query_lower.split())
        
        # Basic stop words to ignore (can be expanded)
        stop_words = {'what', 'are', 'is', 'for', 'the', 'in', 'of', 'how', 'to', 'a', 'an'}
        query_words = query_words - stop_words
        
        results = []
        
        for filename, content in self.data.items():
            # Filter by category if specified
            if category and content.get("category") != category:
                continue
            
            for item in content.get("items", []):
                title = item.get("title", "").lower()
                text = item.get("content", "").lower()
                
                # Check if any significant word from query is in title
                # Or if the title/content contains the query (substring)
                if any(word in title for word in query_words) or query_lower in text:
                    results.append({
                        "title": item.get("title"),
                        "content": item.get("content"),
                        "source": filename,
                        "category": content.get("category")
                    })
        
        return results

    
    def get_tax_slabs(self, regime: str = "new", fy: str = "2024-25") -> Dict:
        """Get income tax slabs for specified regime and FY"""
        tax_data = self.data.get("income_tax_2024", {})
        
        for item in tax_data.get("items", []):
            if regime in item.get("title", "").lower() and "slabs" in item.get("title", "").lower():
                return {
                    "regime": regime,
                    "fy": fy,
                    "slabs": item.get("content"),
                    "source": "official_it_act"
                }
        
        return {}
    
    def get_deduction_info(self, section: str) -> Optional[Dict]:
        """Get deduction details for a specific section (e.g., 80C, 80D)"""
        section_lower = section.lower()
        
        tax_data = self.data.get("income_tax_2024", {})
        
        for item in tax_data.get("items", []):
            if section_lower in item.get("title", "").lower():
                return {
                    "section": section,
                    "title": item.get("title"),
                    "details": item.get("content"),
                    "source": "income_tax_act_1961"
                }
        
        return None

# Global instance
static_kb = StaticKnowledgeService()

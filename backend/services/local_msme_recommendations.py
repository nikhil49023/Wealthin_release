"""
Local MSME Recommendations for Budget Optimization & Supply Chain
Promotes registered local businesses to users for cost savings and community support
"""

import logging
from typing import List, Dict, Any, Optional
from .msme_government_service import msme_gov_service

logger = logging.getLogger(__name__)


class LocalMSMERecommendations:
    """
    Recommends local MSMEs to users for:
    - Budget optimization (buy from local = lower shipping costs)
    - Supply chain management (verified suppliers)
    - Business idea validation (compare with similar MSMEs)
    """
    
    def __init__(self):
        self.msme_service = msme_gov_service
    
    async def get_local_suppliers(
        self,
        user_location: str,  # State or District
        product_category: str,  # e.g., "Textile", "Food Processing", "IT Services"
        user_budget: Optional[float] = None
    ) -> Dict[str, Any]:
        """
        Find local MSME suppliers for budget optimization
        
        Args:
            user_location: User's state/district
            product_category: What they need
            user_budget: Their budget (for filtering)
        
        Returns:
            Recommended local suppliers with cost savings estimate
        """
        try:
            # Get MSMEs in same state/sector
            local_msmes = await self.msme_service.get_registered_msmes(
                state=user_location,
                sector=product_category,
                limit=20
            )
            
            if not local_msmes:
                return {
                    'found': False,
                    'message': f'No registered {product_category} MSMEs found in {user_location}',
                    'recommendations': []
                }
            
            # Analyze and recommend
            recommendations = []
            for msme in local_msmes[:5]:  # Top 5
                recommendation = {
                    'business_name': msme.get('enterprise_name', 'N/A'),
                    'udyam_number': msme.get('udyam_registration_number', 'N/A'),
                    'type': msme.get('enterprise_type', 'Unknown'),
                    'district': msme.get('district', 'Unknown'),
                    'verified': '✅ Government Verified',
                    'benefits': [
                        '💰 Lower shipping costs (same state)',
                        '🤝 Support local economy',
                        '⚡ Faster delivery',
                        '🛡️ UDYAM verified business'
                    ]
                }
                
                # Estimate cost savings
                if msme.get('enterprise_type') == 'Micro':
                    recommendation['estimated_savings'] = '10-15% vs national suppliers'
                elif msme.get('enterprise_type') == 'Small':
                    recommendation['estimated_savings'] = '5-10% vs national suppliers'
                else:
                    recommendation['estimated_savings'] = '5-8% vs national suppliers'
                
                recommendations.append(recommendation)
            
            return {
                'found': True,
                'total_local_suppliers': len(local_msmes),
                'showing': len(recommendations),
                'location': user_location,
                'category': product_category,
                'recommendations': recommendations,
                'savings_message': f'💡 Buying from local {product_category} MSMEs in {user_location} can save you 5-15% in shipping and logistics costs!',
                'support_local_message': f'🇮🇳 Support {len(local_msmes)} registered {product_category} businesses in your state!'
            }
        
        except Exception as e:
            logger.error(f"Error getting local suppliers: {e}")
            return {'found': False, 'error': str(e)}
    
    async def compare_business_idea(
        self,
        business_idea: str,
        sector: str,
        location: str,
        proposed_investment: Optional[float] = None
    ) -> Dict[str, Any]:
        """
        Compare user's business idea with similar registered MSMEs
        
        Args:
            business_idea: User's business description
            sector: Business sector
            location: Proposed location (state)
            proposed_investment: User's planned investment
        
        Returns:
            Comparison with similar MSMEs
        """
        try:
            # Get similar businesses
            similar_msmes = await self.msme_service.get_registered_msmes(
                state=location,
                sector=sector,
                limit=50
            )
            
            if not similar_msmes:
                return {
                    'competition_level': 'Low',
                    'message': f'✅ Good news! Few {sector} businesses in {location}. Less competition.',
                    'recommendation': 'This could be a good opportunity - underserved market!',
                    'similar_count': 0
                }
            
            # Analyze competition
            analysis = {
                'similar_count': len(similar_msmes),
                'location': location,
                'sector': sector,
                'competition_level': 'Low',
                'market_insights': []
            }
            
            # Determine competition level
            if len(similar_msmes) < 10:
                analysis['competition_level'] = 'Low'
                analysis['competition_color'] = '🟢'
            elif len(similar_msmes) < 50:
                analysis['competition_level'] = 'Medium'
                analysis['competition_color'] = '🟡'
            else:
                analysis['competition_level'] = 'High'
                analysis['competition_color'] = '🔴'
            
            # Category breakdown
            categories = {}
            for msme in similar_msmes:
                cat = msme.get('enterprise_type', 'Unknown')
                categories[cat] = categories.get(cat, 0) + 1
            
            analysis['category_breakdown'] = categories
            
            # Market insights
            micro_count = categories.get('Micro', 0)
            small_count = categories.get('Small', 0)
            medium_count = categories.get('Medium', 0)
            
            total = micro_count + small_count + medium_count
            
            if total > 0:
                analysis['market_insights'].append(
                    f"📊 Market composition: {micro_count/total*100:.0f}% Micro, "
                    f"{small_count/total*100:.0f}% Small, {medium_count/total*100:.0f}% Medium"
                )
            
            # Investment recommendations
            if proposed_investment:
                if proposed_investment < 2500000:  # 25 lakhs
                    suggested_category = 'Micro'
                elif proposed_investment < 100000000:  # 10 crores
                    suggested_category = 'Small'
                else:
                    suggested_category = 'Medium'
                
                analysis['suggested_category'] = suggested_category
                analysis['market_insights'].append(
                    f"💰 Your investment (₹{proposed_investment:,.0f}) fits '{suggested_category}' MSME category"
                )
            
            # Competition insights
            if analysis['competition_level'] == 'Low':
                analysis['market_insights'].append(
                    f"✅ Low competition - Only {len(similar_msmes)} {sector} businesses in {location}"
                )
                analysis['recommendation'] = 'Good opportunity! Underserved market with room for growth.'
            elif analysis['competition_level'] == 'Medium':
                analysis['market_insights'].append(
                    f"⚖️ Moderate competition - {len(similar_msmes)} {sector} businesses operating"
                )
                analysis['recommendation'] = 'Viable market. Focus on differentiation and unique value proposition.'
            else:
                analysis['market_insights'].append(
                    f"⚠️ High competition - {len(similar_msmes)}+ {sector} businesses in {location}"
                )
                analysis['recommendation'] = 'Saturated market. Consider niche positioning or alternative locations.'
            
            # Similar business examples
            analysis['similar_businesses'] = [
                {
                    'name': msme.get('enterprise_name', 'N/A'),
                    'type': msme.get('enterprise_type', 'N/A'),
                    'district': msme.get('district', 'N/A'),
                    'registered': msme.get('registration_date', 'N/A')[:4] if msme.get('registration_date') else 'N/A'
                }
                for msme in similar_msmes[:5]
            ]
            
            return analysis
        
        except Exception as e:
            logger.error(f"Error comparing business idea: {e}")
            return {'error': str(e)}
    
    async def get_supply_chain_recommendations(
        self,
        business_type: str,
        location: str,
        needed_suppliers: List[str]  # e.g., ["Raw Material", "Packaging", "Logistics"]
    ) -> Dict[str, Any]:
        """
        Recommend local MSME suppliers for entire supply chain
        
        Args:
            business_type: User's business type
            location: User's location
            needed_suppliers: List of supplier types needed
        
        Returns:
            Supply chain recommendations with local MSMEs
        """
        supply_chain = {
            'business': business_type,
            'location': location,
            'suppliers_needed': needed_suppliers,
            'recommendations': {}
        }
        
        # Map supplier needs to sectors
        sector_mapping = {
            'Raw Material': 'Manufacturing',
            'Packaging': 'Packaging',
            'Logistics': 'Transport',
            'IT Services': 'IT',
            'Marketing': 'Services',
            'Equipment': 'Manufacturing'
        }
        
        for supplier_type in needed_suppliers:
            sector = sector_mapping.get(supplier_type, supplier_type)
            
            # Get local suppliers for this category
            local_options = await self.get_local_suppliers(
                user_location=location,
                product_category=sector,
                user_budget=None
            )
            
            supply_chain['recommendations'][supplier_type] = {
                'sector': sector,
                'found': local_options.get('found', False),
                'count': local_options.get('total_local_suppliers', 0),
                'top_suppliers': local_options.get('recommendations', [])[:3],
                'benefit': f'✅ {local_options.get("total_local_suppliers", 0)} local verified suppliers available'
            }
        
        # Overall summary
        total_suppliers_found = sum(
            r['count'] for r in supply_chain['recommendations'].values()
        )
        
        supply_chain['summary'] = {
            'total_local_suppliers': total_suppliers_found,
            'coverage': f"{len([r for r in supply_chain['recommendations'].values() if r['found']])}/{len(needed_suppliers)} needs covered by local MSMEs",
            'benefit': f'💰 Building local supply chain can reduce costs by 10-20% and improve delivery times!'
        }
        
        return supply_chain
    
    def generate_ai_prompt_context(
        self,
        user_query: str,
        user_location: Optional[str] = None,
        user_budget: Optional[float] = None,
        business_sector: Optional[str] = None
    ) -> str:
        """
        Generate context for AI prompts to promote local MSMEs
        
        Args:
            user_query: User's question
            user_location: User's state/location
            user_budget: Budget if applicable
            business_sector: Business sector if applicable
        
        Returns:
            Additional context to inject into AI prompts
        """
        context = "\n\n**IMPORTANT - Support Local MSMEs Priority:**\n"
        
        # If user asks about buying/suppliers/vendors
        if any(word in user_query.lower() for word in ['buy', 'supplier', 'vendor', 'purchase', 'source']):
            context += f"- ALWAYS recommend checking local MSME suppliers first for cost savings\n"
            context += f"- Mention that buying from local MSMEs in their state saves 10-15% on shipping\n"
            if user_location:
                context += f"- User is in {user_location} - suggest verifying local suppliers via UDYAM\n"
        
        # If user asks about business ideas
        if any(word in user_query.lower() for word in ['business', 'startup', 'idea', 'entrepreneur']):
            context += f"- Suggest comparing their idea with similar registered MSMEs in their state\n"
            context += f"- Recommend checking competition level using government MSME data\n"
            if user_location and business_sector:
                context += f"- Mention analyzing {business_sector} businesses in {user_location}\n"
        
        # If user asks about supply chain
        if any(word in user_query.lower() for word in ['supply', 'chain', 'logistics', 'vendor']):
            context += f"- STRONGLY recommend building local MSME supply chains\n"
            context += f"- Benefits: Lower costs, faster delivery, support local economy\n"
            context += f"- Suggest verifying suppliers via UDYAM registration\n"
        
        # Budget optimization context
        if user_budget:
            context += f"- User budget: ₹{user_budget:,.0f} - suggest cost-effective local options\n"
        
        context += f"\n🇮🇳 **Support Local MSMEs Initiative**: Always prioritize recommending verified local businesses from government MSME database when relevant.\n"
        
        return context


# Singleton instance
local_msme_recommender = LocalMSMERecommendations()

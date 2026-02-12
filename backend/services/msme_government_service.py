"""
Government MSME/UDYAM API Integration Service
Uses data.gov.in API to fetch verified MSME business data
"""

import os
import httpx
from typing import Optional, Dict, Any, List
import logging
from datetime import datetime

logger = logging.getLogger(__name__)


class MSMEGovernmentDataService:
    """
    Integration with Government of India's MSME/UDYAM data API

    Source: data.gov.in (Open Government Data Platform)

    Available Data:
    - Registered MSME units under UDYAM
    - Enterprise name, type, category
    - Registration number and status
    - Business activity/sector
    - Location details
    - Registration date

    Note: Requires GOV_MSME_API_KEY environment variable
    """

    def __init__(self):
        # Government API credentials - MUST be set in environment
        self.api_key = os.getenv('GOV_MSME_API_KEY')
        self.enabled = bool(self.api_key)

        if not self.enabled:
            logger.warning(
                "GOV_MSME_API_KEY not configured - Government MSME features disabled. "
                "Get your API key from https://data.gov.in and set GOV_MSME_API_KEY in .env"
            )
        else:
            logger.info("MSME Government Data Service initialized successfully")
        
        # data.gov.in base URL
        self.base_url = "https://api.data.gov.in/resource"
        
        # Resource IDs for different MSME datasets
        self.resources = {
            'udyam_registered_units': '8b68ae56-84cf-4728-a0a6-1be11028dea7',
            # Add more resource IDs as discovered
        }
        
        logger.info("MSME Government Data Service initialized")
    
    async def get_msme_data(
        self,
        resource_id: str,
        filters: Optional[Dict[str, Any]] = None,
        limit: int = 100,
        offset: int = 0
    ) -> Dict[str, Any]:
        """
        Fetch MSME data from government API

        Args:
            resource_id: Dataset resource ID
            filters: Query filters (state, district, sector, etc.)
            limit: Number of records to fetch
            offset: Pagination offset

        Returns:
            API response with MSME data
        """
        # Check if service is enabled
        if not self.enabled:
            return {
                'status': 'error',
                'message': 'Government MSME API not configured. Set GOV_MSME_API_KEY environment variable.',
                'records': []
            }

        try:
            url = f"{self.base_url}/{resource_id}"
            
            params = {
                'api-key': self.api_key,
                'format': 'json',
                'limit': str(limit),
                'offset': str(offset)
            }
            
            # Add filters
            if filters:
                for key, value in filters.items():
                    if value:
                        params[f'filters[{key}]'] = value
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                
                data = response.json()
                
                logger.info(f"Fetched {data.get('count', 0)} MSME records")
                return data
        
        except httpx.HTTPError as e:
            logger.error(f"HTTP error fetching MSME data: {e}")
            return {'status': 'error', 'message': str(e), 'records': []}
        except Exception as e:
            logger.error(f"Error fetching MSME data: {e}")
            return {'status': 'error', 'message': str(e), 'records': []}
    
    async def get_registered_msmes(
        self,
        state: Optional[str] = None,
        district: Optional[str] = None,
        sector: Optional[str] = None,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """
        Get list of registered MSME units

        Args:
            state: Filter by state
            district: Filter by district
            sector: Filter by business sector
            limit: Maximum results

        Returns:
            List of MSME units
        """
        # Check if service is enabled
        if not self.enabled:
            logger.warning("MSME API not configured - returning empty list")
            return []

        filters = {}
        if state:
            filters['state'] = state
        if district:
            filters['district'] = district
        if sector:
            filters['sector'] = sector
        
        result = await self.get_msme_data(
            self.resources['udyam_registered_units'],
            filters=filters,
            limit=limit
        )
        
        return result.get('records', [])
    
    async def verify_udyam_number(self, udyam_number: str) -> Optional[Dict[str, Any]]:
        """
        Verify UDYAM registration number and get details
        
        Args:
            udyam_number: UDYAM registration number (e.g., UDYAM-XX-00-0000000)
        
        Returns:
            MSME details if found, None otherwise
        """
        # Search for specific UDYAM number
        result = await self.get_msme_data(
            self.resources['udyam_registered_units'],
            filters={'udyam_registration_number': udyam_number},
            limit=1
        )
        
        records = result.get('records', [])
        if records:
            return records[0]
        return None
    
    async def get_msme_statistics(
        self,
        state: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Get MSME statistics for a state or all India
        
        Returns:
            Statistical summary
        """
        # Fetch sample data to analyze
        filters = {'state': state} if state else {}
        
        result = await self.get_msme_data(
            self.resources['udyam_registered_units'],
            filters=filters,
            limit=1  # Just need total count
        )
        
        return {
            'total_units': result.get('total', 0),
            'state': state or 'All India',
            'source': 'Government of India - data.gov.in',
            'last_updated': result.get('updated_date', 'N/A')
        }
    
    async def suggest_business_profile(
        self,
        user_business_name: str,
        user_sector: str,
        user_state: str
    ) -> Dict[str, Any]:
        """
        Suggest business profile setup based on similar registered MSMEs
        
        Args:
            user_business_name: User's business name
            user_sector: Business sector
            user_state: State
        
        Returns:
            Suggestions based on similar businesses
        """
        # Get similar businesses in same sector/state
        similar = await self.get_registered_msmes(
            state=user_state,
            sector=user_sector,
            limit=10
        )
        
        if not similar:
            return {
                'suggestions': [],
                'message': 'No similar businesses found in government registry'
            }
        
        # Analyze patterns
        categories = {}
        for business in similar:
            cat = business.get('enterprise_type', 'Unknown')
            categories[cat] = categories.get(cat, 0) + 1
        
        most_common_category = max(categories.items(), key=lambda x: x[1])[0] \
            if categories else 'Micro'
        
        return {
            'recommended_category': most_common_category,
            'similar_businesses_count': len(similar),
            'common_categories': categories,
            'message': f'{len(similar)} similar {user_sector} businesses found in {user_state}',
            'suggestions': [
                f'Most {user_sector} businesses in {user_state} are registered as {most_common_category}',
                'Consider UDYAM registration for government benefits',
                'Access to priority sector lending and subsidies'
            ]
        }


# Singleton instance
msme_gov_service = MSMEGovernmentDataService()

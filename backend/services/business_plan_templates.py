"""
Business Plan Templates
Pre-built responses for common brainstorming queries
Reduces GPT-4o usage by providing instant, structured answers
"""

from typing import Dict, Any, Optional


class BusinessPlanTemplates:
    """Templates for common business planning tasks"""

    @staticmethod
    def generate_outline(
        business_name: Optional[str] = None,
        business_type: Optional[str] = None,
        location: Optional[str] = None
    ) -> Dict[str, Any]:
        """Generate a business plan outline"""

        business_display = business_name or business_type or "Your Business"
        location_str = f" in {location}" if location else ""

        return {
            'type': 'business_plan_outline',
            'title': f"Business Plan for {business_display}{location_str}",
            'sections': [
                {
                    'section': '1. Executive Summary',
                    'description': 'Overview of your business concept, mission, and objectives',
                    'key_points': [
                        'Business name and location',
                        'Products/services offered',
                        'Target market',
                        'Unique value proposition',
                        'Financial highlights',
                        'Funding requirements'
                    ]
                },
                {
                    'section': '2. Business Description',
                    'description': 'Detailed information about your business',
                    'key_points': [
                        'Industry background',
                        'Business structure (proprietorship, partnership, pvt ltd)',
                        'Nature of business',
                        'MSME registration details'
                    ]
                },
                {
                    'section': '3. Market Analysis',
                    'description': 'Research on your target market and competition',
                    'key_points': [
                        'Target customer demographics',
                        'Market size and growth potential',
                        'Competitor analysis',
                        'Market trends',
                        'Entry barriers'
                    ]
                },
                {
                    'section': '4. Organization & Management',
                    'description': 'Your team and organizational structure',
                    'key_points': [
                        'Organizational chart',
                        'Key team members and roles',
                        'Advisory board (if any)',
                        'Staffing requirements'
                    ]
                },
                {
                    'section': '5. Products/Services',
                    'description': 'What you will offer to customers',
                    'key_points': [
                        'Product/service descriptions',
                        'Pricing strategy',
                        'Product lifecycle',
                        'Intellectual property (patents, trademarks)'
                    ]
                },
                {
                    'section': '6. Marketing & Sales Strategy',
                    'description': 'How you will attract and retain customers',
                    'key_points': [
                        'Marketing channels (online, offline)',
                        'Sales process',
                        'Customer acquisition cost',
                        'Brand positioning',
                        'Promotional activities'
                    ]
                },
                {
                    'section': '7. Financial Projections',
                    'description': '3-5 year financial forecasts',
                    'key_points': [
                        'Startup costs breakdown',
                        'Revenue projections (monthly for year 1, annual for years 2-5)',
                        'Profit & Loss statement',
                        'Cash flow projections',
                        'Break-even analysis',
                        'Key financial ratios (DSCR, ROI)'
                    ]
                },
                {
                    'section': '8. Funding Requirements',
                    'description': 'Capital needed and sources',
                    'key_points': [
                        'Total capital requirement',
                        'Own contribution vs. loan',
                        'Loan repayment plan',
                        'Government schemes eligible for (MUDRA, PMEGP, etc.)'
                    ]
                },
                {
                    'section': '9. Risk Analysis',
                    'description': 'Potential risks and mitigation strategies',
                    'key_points': [
                        'Market risks',
                        'Financial risks',
                        'Operational risks',
                        'Regulatory/compliance risks',
                        'Mitigation strategies'
                    ]
                },
                {
                    'section': '10. Appendices',
                    'description': 'Supporting documents',
                    'key_points': [
                        'Market research data',
                        'Product images/brochures',
                        'Resumes of key team members',
                        'Legal documents',
                        'Letters of intent from suppliers/customers'
                    ]
                }
            ],
            'next_steps': [
                'Research each section thoroughly',
                'Gather market data and competitor information',
                'Prepare 3-year financial projections',
                'Identify suitable funding sources',
                'Review and refine with a mentor/advisor'
            ],
            'estimated_time': '2-4 weeks for comprehensive plan',
            'source': 'template'
        }

    @staticmethod
    def get_funding_guide(
        business_type: Optional[str] = None,
        capital_needed: Optional[float] = None,
        location: Optional[str] = None
    ) -> Dict[str, Any]:
        """Guide to government funding schemes"""

        schemes = [
            {
                'name': 'MUDRA (Pradhan Mantri MUDRA Yojana)',
                'description': 'Micro-units development loan for non-corporate small business sector',
                'loan_amount': 'Up to ₹10 lakhs',
                'categories': [
                    'Shishu: Up to ₹50,000',
                    'Kishore: ₹50,001 to ₹5 lakhs',
                    'Tarun: ₹5,00,001 to ₹10 lakhs'
                ],
                'eligibility': [
                    'Indian citizen',
                    'Business in manufacturing, trading, or service sector',
                    'Income-generating activity'
                ],
                'interest_rate': '8-12% per annum (varies by bank)',
                'collateral': 'No collateral required',
                'website': 'https://www.mudra.org.in'
            },
            {
                'name': 'PMEGP (Prime Minister Employment Generation Programme)',
                'description': 'Credit-linked subsidy program for new micro-enterprises',
                'loan_amount': 'Manufacturing: ₹10 lakh to ₹25 lakh, Services: ₹5 lakh to ₹10 lakh',
                'subsidy': [
                    'General category: 15-25% subsidy',
                    'SC/ST/OBC/Women/Minorities: 25-35% subsidy'
                ],
                'eligibility': [
                    'Age 18 years and above',
                    'At least 8th pass for projects above ₹10 lakhs',
                    'New enterprise only (not existing business)'
                ],
                'margin_money': '5-10% of project cost',
                'website': 'https://www.kviconline.gov.in/pmegp'
            },
            {
                'name': 'Stand-Up India Scheme',
                'description': 'Bank loans for SC/ST and women entrepreneurs',
                'loan_amount': '₹10 lakh to ₹1 crore',
                'eligibility': [
                    'SC/ST and/or Women entrepreneur',
                    'Age 18 years and above',
                    'Loan for greenfield enterprise (manufacturing, services, trading)'
                ],
                'interest_rate': 'Base rate + 3% + tenor premium',
                'repayment': 'Up to 7 years with moratorium',
                'website': 'https://www.standupmitra.in'
            },
            {
                'name': 'Startup India Seed Fund Scheme (SISFS)',
                'description': 'Financial assistance to startups for proof of concept, prototype development',
                'grant': 'Up to ₹20 lakhs as grant',
                'debt': 'Up to ₹50 lakhs as debt',
                'eligibility': [
                    'DPIIT recognized startup',
                    'Incorporated not more than 2 years ago',
                    'Working towards innovation/development'
                ],
                'website': 'https://www.startupindia.gov.in'
            },
            {
                'name': 'Credit Guarantee Fund Trust for Micro and Small Enterprises (CGTMSE)',
                'description': 'Collateral-free credit for MSMEs',
                'guarantee_cover': 'Up to ₹5 crore (75-85% guarantee)',
                'eligibility': [
                    'New or existing MSME',
                    'Loan from eligible lending institution'
                ],
                'fee': '0.75-1% annual service fee',
                'website': 'https://www.cgtmse.in'
            }
        ]

        # Filter schemes based on capital if provided
        recommended = schemes
        if capital_needed:
            if capital_needed <= 1000000:  # ≤ 10 lakhs
                recommended = [s for s in schemes if 'MUDRA' in s['name'] or 'PMEGP' in s['name']]
            elif capital_needed <= 10000000:  # ≤ 1 crore
                recommended = schemes

        return {
            'type': 'funding_guide',
            'schemes': recommended,
            'application_process': {
                'steps': [
                    'Prepare business plan and financial projections',
                    'Gather required documents (ID, address proof, business registration, etc.)',
                    'Visit bank/KVIC office or apply online',
                    'Submit application with supporting documents',
                    'Attend interview/verification',
                    'Loan approval and disbursement'
                ],
                'typical_timeline': '2-6 weeks'
            },
            'required_documents': [
                'Identity proof (Aadhaar, PAN)',
                'Address proof',
                'Business plan/DPR',
                'Educational certificates',
                'Caste certificate (if applicable for SC/ST schemes)',
                'Bank statements (6 months)',
                'Quotations for machinery/equipment',
                'Property documents (if taking secured loan)'
            ],
            'tips': [
                'Apply online for faster processing',
                'Keep all documents ready before application',
                'Prepare a detailed DPR (Detailed Project Report)',
                'Show realistic financial projections',
                'Highlight social impact and job creation'
            ],
            'source': 'template'
        }

    @staticmethod
    def get_dpr_template() -> Dict[str, Any]:
        """Template for Detailed Project Report"""
        return {
            'type': 'dpr_template',
            'title': 'Detailed Project Report (DPR) Template',
            'sections': [
                {
                    'section': 'Promoter Details',
                    'fields': [
                        'Name, Age, Qualification',
                        'Experience in the field',
                        'Address and contact',
                        'PAN, Aadhaar details'
                    ]
                },
                {
                    'section': 'Project Details',
                    'fields': [
                        'Project name and location',
                        'Type of organization (proprietorship, partnership, company)',
                        'Nature of activity (manufacturing/service)',
                        'Product/service description',
                        'Production capacity'
                    ]
                },
                {
                    'section': 'Market Analysis',
                    'fields': [
                        'Demand analysis',
                        'Existing suppliers',
                        'Target customers',
                        'Marketing strategy',
                        'SWOT analysis'
                    ]
                },
                {
                    'section': 'Technical Details',
                    'fields': [
                        'Land and building requirement',
                        'Machinery and equipment list with cost',
                        'Raw material requirements',
                        'Utilities (power, water)',
                        'Manpower requirement'
                    ]
                },
                {
                    'section': 'Financial Details',
                    'fields': [
                        'Total project cost breakdown',
                        'Means of finance (own/loan ratio)',
                        'Working capital calculation',
                        'Revenue projections (5 years)',
                        'Profit & Loss statement',
                        'Cash flow statement',
                        'Balance sheet projections',
                        'Break-even analysis',
                        'Debt Service Coverage Ratio (DSCR)',
                        'Return on Investment (ROI)'
                    ]
                },
                {
                    'section': 'Implementation Schedule',
                    'fields': [
                        'Timeline for each phase',
                        'Milestones',
                        'Monitoring mechanism'
                    ]
                },
                {
                    'section': 'Appendices',
                    'fields': [
                        'Quotations for machinery',
                        'Certificates and licenses',
                        'Land documents',
                        'Market survey reports'
                    ]
                }
            ],
            'format_requirements': {
                'pages': '15-25 pages recommended',
                'font': 'Times New Roman or Arial, 11-12 pt',
                'binding': 'Spiral or perfect binding',
                'copies': '2-3 copies for submission'
            },
            'source': 'template'
        }


# Singleton instance
business_plan_templates = BusinessPlanTemplates()

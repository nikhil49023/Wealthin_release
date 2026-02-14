"""
PDF-grounded MSME scheme compatibility service for Ideas mode.

Source handbook:
"Know Your Lender, Grow Your Business"
Ministry of MSME, Government of India
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional, Tuple


class SchemeCompatibilityService:
    SOURCE_META = {
        "title": "Know Your Lender, Grow Your Business",
        "publisher": "Ministry of MSME, Government of India",
        "document_path": "/home/nikhil/Documents/6140702.pdf",
    }

    # Criteria extracted from Sections 9, 10 and Annexure-B of the handbook.
    SCHEME_RULES: List[Dict[str, Any]] = [
        {
            "id": "pmmy",
            "name": "Pradhan Mantri MUDRA Yojana (PMMY)",
            "category": "scheme",
            "loan_min": 0,
            "loan_max": 2_000_000,  # up to Rs 20 lakh
            "allowed_stages": ["startup", "expansion"],
            "allowed_sectors": ["manufacturing", "trading", "services"],
            "source": "Section 10.1 (Page 35)",
            "notes": [
                "Shishu up to Rs 50,000; Kishor above Rs 50,000 up to Rs 5 lakh; Tarun above Rs 5 lakh up to Rs 10 lakh; Tarun Plus above Rs 10 lakh up to Rs 20 lakh.",
                "PMMY guarantees up to Rs 20 lakh under CGFMU.",
            ],
        },
        {
            "id": "pmegp",
            "name": "Prime Minister Employment Generation Programme (PMEGP)",
            "category": "scheme",
            "allowed_stages": ["startup"],
            "allowed_sectors": ["manufacturing", "services"],
            "source": "Section 10.2 (Page 35)",
            "notes": [
                "Credit-linked subsidy for new micro-enterprises.",
                "Project cap: Rs 50 lakh (manufacturing), Rs 20 lakh (services).",
                "No collateral required for loans up to Rs 10 lakh.",
                "10-day EDP training is mandatory.",
            ],
        },
        {
            "id": "pm_vishwakarma",
            "name": "PM Vishwakarma Scheme",
            "category": "scheme",
            "allowed_stages": ["startup", "expansion"],
            "required_flags": [
                {
                    "field": "is_traditional_artisan",
                    "label": "Traditional artisan/craftsperson status",
                    "blocker_message": "Scheme is for traditional artisans/craftspeople.",
                    "unknown_message": "Confirm whether the applicant is a traditional artisan/craftsperson.",
                }
            ],
            "source": "Section 10.3 (Pages 35-36)",
            "notes": [
                "Includes skill training, toolkit incentive and collateral-free credit support in two tranches.",
                "Provides PM Vishwakarma certificate/ID and Udyam formalization support.",
            ],
        },
        {
            "id": "nulm",
            "name": "National Urban Livelihoods Mission (NULM)",
            "category": "scheme",
            "allowed_stages": ["startup", "expansion"],
            "required_flags": [
                {
                    "field": "is_urban",
                    "label": "Urban location profile",
                    "required_value": True,
                    "blocker_message": "NULM is targeted at urban beneficiaries.",
                    "unknown_message": "Confirm if the enterprise and beneficiary are in an urban area.",
                }
            ],
            "source": "Section 10.4 (Page 36)",
            "notes": [
                "Individuals up to Rs 2 lakh; SHGs up to Rs 10 lakh.",
                "No collateral required for loans up to Rs 10 lakh.",
            ],
        },
        {
            "id": "nrlm",
            "name": "National Rural Livelihoods Mission (NRLM)",
            "category": "scheme",
            "allowed_stages": ["startup", "expansion"],
            "required_flags": [
                {
                    "field": "is_rural",
                    "label": "Rural location profile",
                    "required_value": True,
                    "blocker_message": "NRLM is a rural livelihood program.",
                    "unknown_message": "Confirm if the enterprise and beneficiary are in a rural area.",
                },
                {
                    "field": "is_shg_member",
                    "label": "SHG membership",
                    "required_value": True,
                    "blocker_message": "NRLM support is routed through SHGs.",
                    "unknown_message": "Confirm SHG membership for NRLM eligibility.",
                },
                {
                    "field": "is_women_led_shg",
                    "label": "Women-led SHG status",
                    "required_value": True,
                    "blocker_message": "NRLM prioritizes women-led SHG structures.",
                    "unknown_message": "Confirm whether the SHG is women-led.",
                },
            ],
            "loan_min": 0,
            "loan_max": 1_000_000,  # up to Rs 10 lakh collateral-free
            "source": "Section 10.5 (Page 36)",
            "notes": [
                "Collateral-free loans up to Rs 10 lakh through women-led SHGs.",
                "Supports rural livelihood diversification and financial inclusion.",
            ],
        },
        {
            "id": "mse_gift",
            "name": "MSE-GIFT (Green Investment and Financing for Transformation)",
            "category": "scheme",
            "allowed_stages": ["startup", "expansion"],
            "loan_min": 0,
            "loan_max": 20_000_000,  # up to Rs 2 crore term loan
            "required_flags": [
                {
                    "field": "wants_green_upgrade",
                    "label": "Green technology adoption objective",
                    "required_value": True,
                    "blocker_message": "MSE-GIFT applies to green technology/clean energy adoption.",
                    "unknown_message": "Confirm whether this is a green-tech or clean-energy upgrade project.",
                }
            ],
            "source": "Section 10.6 (Page 36)",
            "notes": [
                "2% interest subvention on eligible term loans up to Rs 2 crore.",
                "Credit guarantee support up to 75% of eligible loans.",
            ],
        },
        {
            "id": "mse_spice",
            "name": "MSE-SPICE (Scheme for Promotion and Investment in Circular Economy)",
            "category": "scheme",
            "allowed_stages": ["startup", "expansion"],
            "loan_min": 0,
            "loan_max": 5_000_000,  # projects up to Rs 50 lakh
            "required_flags": [
                {
                    "field": "wants_circular_economy_project",
                    "label": "Circular economy / waste management project focus",
                    "required_value": True,
                    "blocker_message": "MSE-SPICE applies to circular economy and waste-management projects.",
                    "unknown_message": "Confirm whether project is in plastic/rubber/e-waste/circular economy.",
                }
            ],
            "source": "Section 10.7 (Page 36)",
            "notes": [
                "Capital subsidy: 25% of plant & machinery, capped at Rs 12.5 lakh.",
                "Promotes EPR and circular-economy compliance.",
            ],
        },
        {
            "id": "gst_sahay",
            "name": "GST Sahay (Invoice Based Financing)",
            "category": "credit_product",
            "allowed_stages": ["startup", "expansion"],
            "required_flags": [
                {
                    "field": "has_gst",
                    "label": "GST registration",
                    "required_value": True,
                    "blocker_message": "GST Sahay requires GST registration.",
                    "unknown_message": "Confirm GST registration status.",
                },
                {
                    "field": "has_udyam",
                    "label": "Udyam registration",
                    "required_value": True,
                    "blocker_message": "GST Sahay requires Udyam-registered MSE profile.",
                    "unknown_message": "Confirm Udyam registration status.",
                },
            ],
            "source": "Section 9.3 (Page 34)",
            "notes": [
                "Invoice-based working capital for purchases/sales; typically disbursal in 24 hours.",
                "Collateral-free and based on GST cash-flow data.",
            ],
        },
        {
            "id": "psb_59_minutes",
            "name": "PSB Loans in 59 Minutes",
            "category": "credit_portal",
            "loan_min": 100_000,      # Rs 1 lakh
            "loan_max": 50_000_000,   # Rs 5 crore
            "allowed_stages": ["startup", "expansion"],
            "source": "Section 9.2 (Page 33)",
            "notes": [
                "Digital multi-lender credit access with automated eligibility analysis.",
                "Can route collateral-free loans where covered under CGTMSE.",
            ],
        },
        {
            "id": "cgtmse_cgs",
            "name": "CGTMSE Credit Guarantee Scheme (CGS)",
            "category": "credit_guarantee",
            "loan_min": 0,
            "loan_max": 100_000_000,  # up to Rs 10 crore
            "allowed_stages": ["startup", "expansion"],
            "source": "Section 1.3 (Page 16)",
            "notes": [
                "Guarantee cover for collateral-free credit to underserved MSE segments.",
                "Supports MSE-GIFT and ADEETIE-linked green financing.",
            ],
        },
        {
            "id": "cgss_startup",
            "name": "Credit Guarantee Scheme for Startups (CGSS)",
            "category": "credit_guarantee",
            "loan_min": 0,
            "loan_max": 200_000_000,  # up to Rs 20 crore
            "allowed_stages": ["startup"],
            "required_flags": [
                {
                    "field": "is_dpiit_recognized",
                    "label": "DPIIT startup recognition",
                    "required_value": True,
                    "blocker_message": "CGSS applies to DPIIT-recognized startups.",
                    "unknown_message": "Confirm DPIIT recognition for startup guarantee eligibility.",
                }
            ],
            "source": "Section 1.3 (Page 16)",
            "notes": [
                "Guarantee cover for eligible startup funding through member institutions.",
                "Preferential guarantee fee for women founders and North-East units.",
            ],
        },
    ]

    BOOL_TRUE = {"true", "yes", "y", "1", "available", "done", "completed", "valid"}
    BOOL_FALSE = {"false", "no", "n", "0", "missing", "not_available", "not done", "pending"}
    PAN_PATTERN = re.compile(r"^[A-Z]{5}[0-9]{4}[A-Z]$")
    GST_PATTERN = re.compile(r"^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$")

    KEYWORDS_STARTUP = ("start", "startup", "new venture", "greenfield", "launch", "set up")
    KEYWORDS_EXPANSION = ("expand", "expansion", "scale", "existing business", "working capital", "grow")

    CORE_DOCUMENTS_BASE = [
        "PAN",
        "Aadhaar",
        "Business address proof",
        "Bank statements (6-12 months)",
        "Udyam registration",
    ]

    def assess(
        self,
        message: str,
        user_profile: Optional[Dict[str, Any]] = None,
        conversation_history: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        profile = self._normalize_profile(message, user_profile or {}, conversation_history or [])
        matches = [self._evaluate_rule(rule, profile) for rule in self.SCHEME_RULES]
        matches.sort(key=lambda item: item["score"], reverse=True)

        compatible = [m for m in matches if m["status"] in {"eligible", "conditional"}]
        not_compatible = [m for m in matches if m["status"] == "not_eligible"]
        legal_readiness = self._evaluate_legal_readiness(profile)

        return {
            "source": self.SOURCE_META,
            "profile": profile,
            "compatible_schemes": compatible[:7],
            "not_compatible_schemes": not_compatible[:7],
            "all_scheme_assessments": matches,
            "legal_readiness": legal_readiness,
        }

    def build_prompt_context(self, report: Dict[str, Any]) -> str:
        profile = report.get("profile", {})
        top = report.get("compatible_schemes", [])[:3]
        legal = report.get("legal_readiness", {})
        missing_docs = legal.get("missing_documents", [])[:4]

        lines = [
            "PDF-GROUNDED MSME COMPATIBILITY CONTEXT (use as hard constraints):",
            f"- Source: {self.SOURCE_META['title']} ({self.SOURCE_META['publisher']}).",
            f"- Inferred stage: {profile.get('business_stage', 'unknown')}.",
            f"- Inferred loan amount: {profile.get('loan_amount_display', 'Not provided')}.",
            f"- Inferred sector: {profile.get('business_sector', 'unknown')}.",
            "Top scheme compatibility signals:",
        ]

        if top:
            for scheme in top:
                scheme_lines = [
                    f"- {scheme['scheme_name']}: {scheme['status'].upper()} (score {scheme['score']}/100).",
                ]
                if scheme["blockers"]:
                    scheme_lines.append(f"  Blockers: {', '.join(scheme['blockers'][:2])}.")
                elif scheme["conditions"]:
                    scheme_lines.append(f"  Conditions: {', '.join(scheme['conditions'][:2])}.")
                lines.extend(scheme_lines)
        else:
            lines.append("- No clear scheme fit yet; collect missing profile details first.")

        lines.append(
            f"Legal readiness status: {legal.get('status', 'unknown')} (score {legal.get('score', 0)}/100)."
        )
        if missing_docs:
            lines.append(f"Critical document gaps: {', '.join(missing_docs)}.")
        lines.append(
            "Do not claim legal eligibility if blockers exist; present conditional steps and document gaps explicitly."
        )
        return "\n".join(lines)

    def render_markdown_summary(self, report: Dict[str, Any]) -> str:
        profile = report.get("profile", {})
        compatible = report.get("compatible_schemes", [])[:4]
        not_compatible = report.get("not_compatible_schemes", [])[:3]
        legal = report.get("legal_readiness", {})

        lines = [
            "### PDF-grounded Scheme Compatibility Check",
            f"- **Business stage:** {profile.get('business_stage', 'unknown')}",
            f"- **Loan ask:** {profile.get('loan_amount_display', 'Not provided')}",
            f"- **Sector:** {profile.get('business_sector', 'unknown')}",
            "",
            "**Most compatible schemes/loans:**",
        ]

        if compatible:
            for item in compatible:
                line = f"- **{item['scheme_name']}** — {item['status'].replace('_', ' ').title()} ({item['score']}/100)"
                if item["conditions"]:
                    line += f" | Conditions: {', '.join(item['conditions'][:2])}"
                lines.append(line)
        else:
            lines.append("- No strong match yet. Provide profile details for accurate eligibility checks.")

        if not_compatible:
            lines.extend(["", "**Currently blocked schemes:**"])
            for item in not_compatible:
                reason = ", ".join(item["blockers"][:2]) if item["blockers"] else "Eligibility mismatch"
                lines.append(f"- **{item['scheme_name']}** — {reason}")

        lines.extend(
            [
                "",
                f"**Legal readiness:** {legal.get('status', 'unknown')} ({legal.get('score', 0)}/100)",
            ]
        )

        if legal.get("missing_documents"):
            lines.append(
                f"- Missing documents: {', '.join(legal['missing_documents'][:6])}"
            )
        if legal.get("critical_risks"):
            lines.append(f"- Critical risks: {', '.join(legal['critical_risks'][:4])}")
        if legal.get("next_actions"):
            lines.append(f"- Next actions: {' | '.join(legal['next_actions'][:4])}")

        lines.extend(
            [
                "- Borrower-right check: ask lender for **KFS + APR + all charges disclosure** before sanction.",
                "- Compliance note: NPA risk begins if dues remain unpaid for **more than 90 days**.",
            ]
        )
        return "\n".join(lines)

    def render_authoritative_response(
        self,
        report: Dict[str, Any],
        rag_payload: Optional[Dict[str, Any]] = None,
    ) -> str:
        """
        Deterministic, handbook-grounded response for compliance/scheme queries.
        Avoids model hallucination by using only local rules + local RAG snippets.
        """
        profile = report.get("profile", {})
        compatible = report.get("compatible_schemes", [])[:4]
        blocked = report.get("not_compatible_schemes", [])[:3]
        legal = report.get("legal_readiness", {})
        rag_matches = (rag_payload or {}).get("matches", [])[:4]

        lines = [
            "## Authoritative MSME Scheme & Legal Check (Handbook-grounded)",
            f"- Business stage: **{profile.get('business_stage', 'unknown')}**",
            f"- Loan ask: **{profile.get('loan_amount_display', 'Not provided')}**",
            f"- Sector: **{profile.get('business_sector', 'unknown')}**",
            "",
            "### Best-fit options (deterministic)",
        ]

        if compatible:
            for item in compatible:
                facts = self._fact_snippet_for_scheme(item.get("scheme_id", ""), profile)
                conditions = item.get("conditions") or []
                condition_text = f" | Conditions: {', '.join(conditions[:2])}" if conditions else ""
                lines.append(
                    f"- **{item.get('scheme_name')}** ({item.get('status', '').replace('_', ' ').title()}, {item.get('score')}/100): {facts}{condition_text}"
                )
        else:
            lines.append("- No clear eligible scheme with current profile details.")

        if blocked:
            lines.extend(["", "### Not currently eligible"])
            for item in blocked:
                reason = ", ".join((item.get("blockers") or [])[:2]) or "Eligibility mismatch"
                lines.append(f"- **{item.get('scheme_name')}**: {reason}")

        lines.extend(
            [
                "",
                f"### Legal readiness: **{legal.get('status', 'unknown')}** ({legal.get('score', 0)}/100)",
            ]
        )

        mandatory_docs = self._mandatory_documents_for_profile(profile)
        lines.append(f"- Mandatory documents: {', '.join(mandatory_docs)}")

        missing_docs = legal.get("missing_documents", [])
        if missing_docs:
            lines.append(f"- Missing right now: {', '.join(missing_docs[:8])}")
        pending_info = legal.get("pending_information", [])
        if pending_info:
            lines.append(f"- Still to confirm: {', '.join(pending_info[:6])}")

        lines.extend(
            [
                "- Borrower rights: Ask for **KFS + APR + all charge disclosures** before signing.",
                "- Collateral norm: For MSE loans up to **Rs 10 lakh**, collateral should generally not be demanded as per RBI guidance.",
                "- Default risk: Delays beyond **90 days** can trigger NPA classification.",
            ]
        )

        if rag_matches:
            lines.extend(["", "### Handbook references used"])
            for match in rag_matches:
                lines.append(f"- {match.get('section', 'Section')}: {match.get('title', 'Reference')}")

        lines.extend(
            [
                "",
                "### Next actions",
                "- Complete missing registrations/documents before applying.",
                "- Submit DPR/project report with realistic financial assumptions.",
                "- Apply via scheme portal/bank and request application acknowledgement/CPTS tracking.",
            ]
        )
        return "\n".join(lines)

    def _normalize_profile(
        self,
        message: str,
        raw_profile: Dict[str, Any],
        conversation_history: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        combined_text = (message or "").strip()
        if conversation_history:
            history_text = " ".join(
                (msg.get("content") or "").strip() for msg in conversation_history[-6:] if msg.get("content")
            )
            if history_text:
                combined_text = f"{history_text}\n{combined_text}".strip()

        loan_amount = self._to_amount(
            self._pick(raw_profile, ["loan_amount", "capital_required", "funding_needed", "project_cost", "budget"])
        )
        if loan_amount is None:
            loan_amount = self._extract_amount_from_text(combined_text)

        stage = self._normalize_stage(self._pick(raw_profile, ["business_stage", "stage", "venture_stage"]))
        if stage == "unknown":
            stage = self._infer_stage_from_text(combined_text)

        sector = self._normalize_sector(self._pick(raw_profile, ["business_sector", "sector", "industry", "activity"]))
        if sector == "unknown":
            sector = self._infer_sector_from_text(combined_text)

        location_type = self._normalize_location_type(
            self._pick(raw_profile, ["location_type", "area_type", "location"])
        )
        if location_type == "unknown":
            location_type = self._infer_location_type_from_text(combined_text)

        profile = {
            "business_stage": stage,
            "loan_amount": int(loan_amount) if loan_amount is not None else None,
            "loan_amount_display": self._display_amount(loan_amount),
            "business_sector": sector,
            "location_type": location_type,
            "is_rural": location_type == "rural",
            "is_urban": location_type == "urban",
            "is_woman_entrepreneur": self._to_bool(
                self._pick(raw_profile, ["is_woman_entrepreneur", "woman_entrepreneur", "is_woman"])
            ),
            "is_dpiit_recognized": self._to_bool(
                self._pick(raw_profile, ["is_dpiit_recognized", "dpiit_recognized", "has_dpiit"])
            ),
            "is_traditional_artisan": self._to_bool(
                self._pick(raw_profile, ["is_traditional_artisan", "traditional_artisan", "is_artisan"])
            ),
            "is_shg_member": self._to_bool(self._pick(raw_profile, ["is_shg_member", "shg_member"])),
            "is_women_led_shg": self._to_bool(
                self._pick(raw_profile, ["is_women_led_shg", "women_led_shg"])
            ),
            "has_udyam": self._to_bool(self._pick(raw_profile, ["has_udyam", "udyam_registered", "udyam"])),
            "has_gst": self._to_bool(self._pick(raw_profile, ["has_gst", "gst_registered", "gstin"])),
            "has_pan": self._to_bool(self._pick(raw_profile, ["has_pan", "pan"])),
            "has_aadhaar": self._to_bool(self._pick(raw_profile, ["has_aadhaar", "aadhaar", "aadhar"])),
            "has_bank_statements": self._to_bool(
                self._pick(raw_profile, ["has_bank_statements", "bank_statements"])
            ),
            "has_business_address_proof": self._to_bool(
                self._pick(raw_profile, ["has_business_address_proof", "business_address_proof"])
            ),
            "has_financial_statements": self._to_bool(
                self._pick(raw_profile, ["has_financial_statements", "financial_statements"])
            ),
            "has_project_report": self._to_bool(self._pick(raw_profile, ["has_project_report", "dpr_ready"])),
            "has_audited_financials": self._to_bool(
                self._pick(raw_profile, ["has_audited_financials", "audited_financials"])
            ),
            "has_previous_tarun_repayment": self._to_bool(
                self._pick(raw_profile, ["has_previous_tarun_repayment", "tarun_repaid"])
            ),
            "wants_green_upgrade": self._to_bool(
                self._pick(raw_profile, ["wants_green_upgrade", "green_upgrade"])
            ),
            "wants_circular_economy_project": self._to_bool(
                self._pick(raw_profile, ["wants_circular_economy_project", "circular_economy_project"])
            ),
            "itr_years_filed": self._to_int(self._pick(raw_profile, ["itr_years_filed", "itr_years"])),
            "cibil_score": self._to_int(self._pick(raw_profile, ["cibil_score", "credit_score"])),
            "days_past_due": self._to_int(self._pick(raw_profile, ["days_past_due", "dpd"])),
        }

        if profile["is_traditional_artisan"] is None and "vishwakarma" in combined_text.lower():
            profile["is_traditional_artisan"] = True
        if profile["is_shg_member"] is None and "shg" in combined_text.lower():
            profile["is_shg_member"] = True
        if profile["wants_green_upgrade"] is None and any(
            k in combined_text.lower() for k in ("green", "solar", "clean energy", "energy efficiency")
        ):
            profile["wants_green_upgrade"] = True
        if profile["wants_circular_economy_project"] is None and any(
            k in combined_text.lower() for k in ("circular", "recycle", "e-waste", "waste management", "plastic")
        ):
            profile["wants_circular_economy_project"] = True

        return profile

    def _evaluate_rule(self, rule: Dict[str, Any], profile: Dict[str, Any]) -> Dict[str, Any]:
        blockers: List[str] = []
        conditions: List[str] = []
        strengths: List[str] = []

        amount = profile.get("loan_amount")
        stage = profile.get("business_stage")
        sector = profile.get("business_sector")

        allowed_stages = rule.get("allowed_stages") or []
        if allowed_stages and stage and stage not in allowed_stages:
            blockers.append(f"Designed for {', '.join(allowed_stages)} cases.")
        elif allowed_stages and stage in allowed_stages:
            strengths.append(f"Stage fit ({stage}).")

        min_amt = rule.get("loan_min")
        max_amt = rule.get("loan_max")
        if amount is None:
            conditions.append("Loan amount not provided.")
        else:
            if min_amt is not None and amount < min_amt:
                blockers.append(f"Minimum supported amount is {self._display_amount(min_amt)}.")
            if max_amt is not None and amount > max_amt:
                blockers.append(f"Exceeds limit of {self._display_amount(max_amt)}.")
            if not blockers:
                strengths.append("Loan range appears compatible.")

        allowed_sectors = rule.get("allowed_sectors") or []
        if allowed_sectors and sector != "unknown":
            if sector not in allowed_sectors:
                blockers.append(f"Sector '{sector}' is outside scope ({', '.join(allowed_sectors)}).")
            else:
                strengths.append(f"Sector fit ({sector}).")
        elif allowed_sectors and sector == "unknown":
            conditions.append("Business sector not confirmed.")

        for req in rule.get("required_flags", []):
            required_value = req.get("required_value", True)
            value = profile.get(req["field"])
            if value is None:
                conditions.append(req.get("unknown_message", f"Confirm {req['label']}."))
            elif value != required_value:
                blockers.append(req.get("blocker_message", f"{req['label']} is required."))
            else:
                strengths.append(f"{req['label']} confirmed.")

        self._apply_special_checks(rule["id"], profile, blockers, conditions, strengths)

        score = 100 - (26 * len(blockers)) - (7 * len(conditions))
        score = max(0, min(100, score))
        status = "eligible"
        if blockers:
            status = "not_eligible"
            score = min(score, 45)
        elif conditions:
            status = "conditional"

        return {
            "scheme_id": rule["id"],
            "scheme_name": rule["name"],
            "category": rule["category"],
            "status": status,
            "score": score,
            "strengths": strengths,
            "conditions": conditions,
            "blockers": blockers,
            "source": rule.get("source"),
            "notes": rule.get("notes", []),
        }

    def _apply_special_checks(
        self,
        scheme_id: str,
        profile: Dict[str, Any],
        blockers: List[str],
        conditions: List[str],
        strengths: List[str],
    ) -> None:
        amount = profile.get("loan_amount")
        sector = profile.get("business_sector")
        stage = profile.get("business_stage")

        if scheme_id == "pmmy" and amount is not None and amount > 1_000_000:
            repaid = profile.get("has_previous_tarun_repayment")
            if repaid is False:
                blockers.append("Tarun Plus needs successful repayment history under Tarun.")
            elif repaid is None:
                conditions.append("For Tarun Plus, confirm prior successful Tarun repayment.")

        if scheme_id == "pmegp" and amount is not None:
            if sector == "manufacturing" and amount > 5_000_000:
                blockers.append("PMEGP manufacturing cap is Rs 50 lakh.")
            elif sector == "services" and amount > 2_000_000:
                blockers.append("PMEGP services cap is Rs 20 lakh.")
            elif sector == "unknown":
                conditions.append("Confirm sector to apply PMEGP project-cost caps.")
            if stage == "expansion":
                blockers.append("PMEGP is meant for new micro-enterprise setup.")

        if scheme_id == "nulm" and amount is not None:
            is_shg = profile.get("is_shg_member")
            limit = 1_000_000 if is_shg else 200_000
            if amount > limit:
                blockers.append(f"NULM amount exceeds {'SHG' if is_shg else 'individual'} cap ({self._display_amount(limit)}).")

        if scheme_id == "gst_sahay" and stage == "startup":
            conditions.append("GST Sahay is strongest where GST invoice trail and operating history exist.")

        if scheme_id == "psb_59_minutes" and amount is not None and amount < 100_000:
            blockers.append("PSB 59 Minutes starts from Rs 1 lakh.")

        if scheme_id == "cgtmse_cgs" and amount is not None and amount <= 1_000_000:
            strengths.append("Loan size aligns with collateral-free norm up to Rs 10 lakh for MSE.")

    def _evaluate_legal_readiness(self, profile: Dict[str, Any]) -> Dict[str, Any]:
        missing: List[str] = []
        pending: List[str] = []
        critical_risks: List[str] = []
        next_actions: List[str] = []

        def check_bool(field: str, label: str) -> None:
            value = profile.get(field)
            if value is False:
                missing.append(label)
            elif value is None:
                pending.append(label)

        check_bool("has_pan", "PAN")
        check_bool("has_aadhaar", "Aadhaar")
        check_bool("has_business_address_proof", "Business address proof")
        check_bool("has_bank_statements", "Bank statements (6-12 months)")

        amount = profile.get("loan_amount")
        stage = profile.get("business_stage")

        if stage == "expansion":
            check_bool("has_gst", "GST registration and returns")
            check_bool("has_financial_statements", "Financial statements (Balance Sheet/P&L/Cash Flow)")
            itr_years = profile.get("itr_years_filed")
            if itr_years is None:
                pending.append("Income Tax Returns filing history")
            elif itr_years < 1:
                missing.append("Latest Income Tax Returns")

        check_bool("has_udyam", "Udyam registration")

        if amount is not None and amount >= 200_000:
            check_bool("has_project_report", "Project report/DPR")
        if amount is not None and amount >= 2_500_000:
            check_bool("has_audited_financials", "Audited financial statements (for higher exposure)")
            itr_years = profile.get("itr_years_filed")
            if itr_years is not None and itr_years < 3:
                missing.append("3-year ITR/balance-sheet history for higher exposure")
            elif itr_years is None:
                pending.append("3-year ITR/balance-sheet history for higher exposure")

        cibil = profile.get("cibil_score")
        if cibil is not None and cibil < 650:
            critical_risks.append("Low credit score (<650) may increase cost of credit.")

        dpd = profile.get("days_past_due")
        if dpd is not None and dpd > 90:
            critical_risks.append("Repayment overdue >90 days can trigger NPA classification.")

        if missing:
            next_actions.append("Close mandatory document gaps before applying.")
        if pending:
            next_actions.append("Collect missing profile/legal data for accurate eligibility matching.")

        next_actions.extend(
            [
                "Request Key Fact Statement (KFS) with APR and full charge breakup before loan acceptance.",
                "For digital loans, verify RBI-regulated lender app and cooling-off exit terms.",
                "Use lender acknowledgement/CPTS tracking to monitor decision timelines.",
            ]
        )

        score = 100 - (18 * len(missing)) - (6 * len(pending)) - (18 * len(critical_risks))
        score = max(0, min(100, score))

        if missing or critical_risks:
            status = "not_ready"
        elif pending:
            status = "partially_ready"
        else:
            status = "ready"

        return {
            "status": status,
            "score": score,
            "missing_documents": missing,
            "pending_information": pending,
            "critical_risks": critical_risks,
            "next_actions": next_actions,
            "borrower_rights_checks": [
                "Ask for KFS in a language you understand; verify APR includes all charges.",
                "Ensure all fees/penal charges are explicitly disclosed in loan agreement/KFS.",
                "For MSE loans up to Rs 10 lakh, collateral should generally not be demanded as per RBI guidance.",
            ],
        }

    def _mandatory_documents_for_profile(self, profile: Dict[str, Any]) -> List[str]:
        docs = list(self.CORE_DOCUMENTS_BASE)
        stage = profile.get("business_stage")
        amount = profile.get("loan_amount") or 0

        if stage == "startup":
            docs.append("Project report/DPR")
        else:
            docs.extend(
                [
                    "GST registration and returns",
                    "Income Tax Returns (past 1-3 years)",
                    "Financial statements (Balance Sheet/P&L/Cash Flow)",
                ]
            )

        if amount >= 2_500_000:
            docs.append("Audited financial statements (higher exposure cases)")

        # Stable order + de-duplication
        seen = set()
        ordered: List[str] = []
        for item in docs:
            if item in seen:
                continue
            seen.add(item)
            ordered.append(item)
        return ordered

    def _fact_snippet_for_scheme(self, scheme_id: str, profile: Dict[str, Any]) -> str:
        if scheme_id == "pmegp":
            return (
                "For new micro-enterprises; project cap is Rs 50 lakh (manufacturing) and Rs 20 lakh (services); "
                "collateral-free support up to Rs 10 lakh with subsidy-linked structure."
            )
        if scheme_id == "pmmy":
            return (
                "Supports micro enterprises up to Rs 20 lakh (Shishu/Kishor/Tarun/Tarun Plus slabs); "
                "loan amount tier should align with category conditions."
            )
        if scheme_id == "psb_59_minutes":
            return "Digital lender-matching portal for MSME credit from Rs 1 lakh to Rs 5 crore."
        if scheme_id == "cgtmse_cgs":
            return (
                "Credit guarantee support for collateral-free MSE lending; handbook indicates coverage bands "
                "(typically around 75%-85%, not universal 100%)."
            )
        if scheme_id == "gst_sahay":
            return "Invoice-based financing for GST-registered + Udyam-registered MSEs."
        if scheme_id == "nrlm":
            return "Rural women-led SHG model with collateral-free credit up to Rs 10 lakh."
        if scheme_id == "nulm":
            return "Urban livelihood model: individuals up to Rs 2 lakh, SHGs up to Rs 10 lakh."
        if scheme_id == "mse_gift":
            return "Green technology transition support with 2% interest subvention on eligible term loans up to Rs 2 crore."
        if scheme_id == "mse_spice":
            return "Circular-economy projects up to Rs 50 lakh with capped capital subsidy support."
        if scheme_id == "cgss_startup":
            return "Credit guarantee route for DPIIT-recognized startups through eligible member institutions."
        if scheme_id == "pm_vishwakarma":
            return "Targeted support for traditional artisans/craftspeople with training, toolkit and credit support."
        return "See handbook-linked scheme notes for eligibility and limits."

    def _pick(self, data: Dict[str, Any], keys: List[str]) -> Any:
        for key in keys:
            if key in data and data[key] not in ("", None):
                return data[key]
        return None

    def _to_bool(self, value: Any) -> Optional[bool]:
        if value is None:
            return None
        if isinstance(value, bool):
            return value
        if isinstance(value, (int, float)):
            return bool(value)
        if isinstance(value, str):
            text = value.strip()
            low = text.lower()
            if low in self.BOOL_TRUE:
                return True
            if low in self.BOOL_FALSE:
                return False
            if self.PAN_PATTERN.match(text.upper()) or text.isdigit():
                return True
            if self.GST_PATTERN.match(text.upper()):
                return True
        return None

    def _to_int(self, value: Any) -> Optional[int]:
        if value is None:
            return None
        if isinstance(value, int):
            return value
        if isinstance(value, float):
            return int(value)
        if isinstance(value, str):
            digits = re.sub(r"[^0-9]", "", value)
            return int(digits) if digits else None
        return None

    def _to_amount(self, value: Any) -> Optional[float]:
        if value is None:
            return None
        if isinstance(value, (int, float)):
            return float(value)
        if not isinstance(value, str):
            return None
        return self._parse_amount_text(value)

    def _parse_amount_text(self, text: str) -> Optional[float]:
        raw = (text or "").lower().replace(",", "").strip()
        if not raw:
            return None
        match = re.search(r"([0-9]+(?:\.[0-9]+)?)\s*(crore|cr|lakh|lac|lk|thousand|k)?", raw)
        if not match:
            return None
        value = float(match.group(1))
        unit = match.group(2) or ""
        if unit in {"crore", "cr"}:
            return value * 10_000_000
        if unit in {"lakh", "lac", "lk"}:
            return value * 100_000
        if unit in {"thousand", "k"}:
            return value * 1_000
        return value

    def _extract_amount_from_text(self, text: str) -> Optional[float]:
        lower = (text or "").lower()
        pattern = re.compile(r"(?:₹|rs\.?|inr)?\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?)\s*(crore|cr|lakh|lac|lk|thousand|k)?")
        candidates: List[Tuple[float, int]] = []
        for match in pattern.finditer(text or ""):
            value_text = match.group(1)
            unit = match.group(2) or ""
            context_start = max(0, match.start() - 24)
            context_end = min(len(lower), match.end() + 24)
            context = lower[context_start:context_end]
            if not any(k in context for k in ("loan", "fund", "capital", "project", "investment", "budget")):
                continue
            base = float(value_text.replace(",", ""))
            multiplier = 1.0
            if unit in {"crore", "cr"}:
                multiplier = 10_000_000
            elif unit in {"lakh", "lac", "lk"}:
                multiplier = 100_000
            elif unit in {"thousand", "k"}:
                multiplier = 1_000
            candidates.append((base * multiplier, match.start()))
        if not candidates:
            return None
        candidates.sort(key=lambda item: item[0], reverse=True)
        return candidates[0][0]

    def _normalize_stage(self, stage: Any) -> str:
        if stage is None:
            return "unknown"
        low = str(stage).strip().lower()
        if any(word in low for word in ("expand", "expansion", "existing", "scale")):
            return "expansion"
        if any(word in low for word in ("startup", "start", "new", "greenfield", "launch")):
            return "startup"
        return "unknown"

    def _infer_stage_from_text(self, text: str) -> str:
        low = (text or "").lower()
        if any(word in low for word in self.KEYWORDS_EXPANSION):
            return "expansion"
        if any(word in low for word in self.KEYWORDS_STARTUP):
            return "startup"
        return "startup"

    def _normalize_sector(self, sector: Any) -> str:
        if sector is None:
            return "unknown"
        return self._infer_sector_from_text(str(sector))

    def _infer_sector_from_text(self, text: str) -> str:
        low = (text or "").lower()
        if any(k in low for k in ("circular", "e-waste", "recycl", "waste management", "plastic", "rubber")):
            return "circular_economy"
        if any(k in low for k in ("green", "clean energy", "solar", "energy efficiency")):
            return "green_project"
        if any(k in low for k in ("artisan", "craft", "vishwakarma", "weaver", "carpenter")):
            return "traditional_artisan"
        if any(k in low for k in ("manufactur", "factory", "plant", "production", "machinery")):
            return "manufacturing"
        if any(k in low for k in ("trade", "trading", "retail", "wholesale", "store", "shop")):
            return "trading"
        if any(k in low for k in ("service", "consult", "agency", "clinic", "salon", "restaurant", "food")):
            return "services"
        return "unknown"

    def _normalize_location_type(self, location: Any) -> str:
        if location is None:
            return "unknown"
        return self._infer_location_type_from_text(str(location))

    def _infer_location_type_from_text(self, text: str) -> str:
        low = (text or "").lower()
        if any(k in low for k in ("rural", "village", "gram", "panchayat")):
            return "rural"
        if any(k in low for k in ("urban", "city", "municipal", "metro")):
            return "urban"
        return "unknown"

    def _display_amount(self, amount: Optional[float]) -> str:
        if amount is None:
            return "Not provided"
        value = float(amount)
        if value >= 10_000_000:
            return f"Rs {value / 10_000_000:.2f} crore"
        if value >= 100_000:
            return f"Rs {value / 100_000:.2f} lakh"
        return f"Rs {value:,.0f}"


scheme_compatibility_service = SchemeCompatibilityService()

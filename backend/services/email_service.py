"""
Email Parsing Service
Fetches emails from IMAP, extracts PDF attachments, and parses transactions.
"""
import imaplib
import email
import os
import tempfile
import logging
from email.header import decode_header
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from services.pdf_parser_advanced import pdf_parser_service

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class EmailService:
    def __init__(self):
        self.imap_server = "imap.gmail.com" # Default to Gmail
        
    def connect(self, email_user: str, email_pass: str):
        try:
            # Create an IMAP4 class with SSL 
            mail = imaplib.IMAP4_SSL(self.imap_server)
            # Authenticate
            mail.login(email_user, email_pass)
            return mail
        except Exception as e:
            logger.error(f"Email connection failed: {e}")
            raise Exception(f"Failed to connect to email: {str(e)}")

    async def fetch_and_parse_emails(
        self, 
        email_user: str, 
        email_pass: str, 
        days_back: int = 30,
        search_keywords: List[str] = ["Notification", "Statement", "Alert", "Transaction", "Bank"]
    ) -> Dict[str, Any]:
        """
        Fetch emails, extract PDFs, parse transactions.
        Returns aggregated results.
        """
        mail = None
        temp_files = []
        all_transactions = []
        processed_count = 0
        
        try:
            mail = self.connect(email_user, email_pass)
            mail.select("inbox")
            
            # Calculate date for search
            date_since = (datetime.now() - timedelta(days=days_back)).strftime("%d-%b-%Y")
            
            # Search for emails with attachments
            # Note: IMAP search is limited. We search for generic criteria then filter.
            # Searching for 'All' then filtering in python is slow.
            # Let's search for "SINCE {date}"
            status, messages = mail.search(None, f'(SINCE "{date_since}")')
            
            if status != "OK":
                return {"status": "error", "message": "Failed to search emails"}
            
            email_ids = messages[0].split()
            # Process latest first
            email_ids = email_ids[::-1]
            
            # Limit to last 50 emails to avoid timeout
            email_ids = email_ids[:50]
            
            logger.info(f"Scanning {len(email_ids)} emails since {date_since}")

            for e_id in email_ids:
                try:
                    res, msg_data = mail.fetch(e_id, "(RFC822)")
                    for response_part in msg_data:
                        if isinstance(response_part, tuple):
                            msg = email.message_from_bytes(response_part[1])
                            subject, encoding = decode_header(msg["Subject"])[0]
                            if isinstance(subject, bytes):
                                subject = subject.decode(encoding if encoding else "utf-8")
                            
                            # Filter by keywords in subject
                            if not any(k.lower() in subject.lower() for k in search_keywords):
                                continue
                                
                            # Check for attachments
                            if msg.get_content_maintype() == 'multipart':
                                for part in msg.walk():
                                    if part.get_content_maintype() == 'multipart' or part.get('Content-Disposition') is None:
                                        continue
                                        
                                    filename = part.get_filename()
                                    if filename:
                                        if filename.lower().endswith('.pdf'):
                                            # Save temp file
                                            with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as tmp:
                                                tmp.write(part.get_payload(decode=True))
                                                temp_path = tmp.name
                                                temp_files.append(temp_path)
                                                
                                                # Parse PDF
                                                try:
                                                    result = await pdf_parser_service.extract_transactions(temp_path)
                                                    if result.get('transactions'):
                                                        logger.info(f"Found {len(result['transactions'])} txs in {filename}")
                                                        all_transactions.extend(result['transactions'])
                                                        processed_count += 1
                                                except Exception as e:
                                                    logger.error(f"Error parsing connection: {e}")
                except Exception as e:
                    logger.error(f"Error processing email {e_id}: {e}")
                    continue
            
            try:
                mail.close()
                mail.logout()
            except:
                pass
            
            return {
                "status": "success",
                "processed_emails": processed_count,
                "transactions": all_transactions,
                "count": len(all_transactions)
            }
            
        except Exception as e:
            # Cleanup even on error
            try:
                if mail:
                    mail.logout()
            except:
                pass
            return {"status": "error", "message": str(e)}
        finally:
            # Cleanup temp files
            for p in temp_files:
                if os.path.exists(p):
                    try:
                        os.unlink(p)
                    except:
                        pass

email_service = EmailService()

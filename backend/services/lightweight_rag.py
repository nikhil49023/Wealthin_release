"""
Lightweight RAG using TF-IDF + SQLite for Android compatibility.
Total size: ~2MB vs 500MB for sentence-transformers.
"""

import json
import sqlite3
from pathlib import Path
from typing import List, Dict, Tuple
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
import logging
import os

logger = logging.getLogger(__name__)

class LightweightRAG:
    """
    Android-compatible RAG using TF-IDF for document retrieval.
    No heavy ML dependencies required.
    """
    
    def __init__(self, db_path: str = "data/knowledge_base.db"):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Initialize SQLite database
        self.conn = sqlite3.connect(str(self.db_path), check_same_thread=False)
        self._create_tables()
        
        # TF-IDF vectorizer (lightweight, fast)
        self.vectorizer = None
        self.document_vectors = None
        self.documents = []
        
        logger.info(f"LightweightRAG initialized at {self.db_path}")
    
    def _create_tables(self):
        """Create tables for knowledge base storage"""
        cursor = self.conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS documents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                doc_id TEXT UNIQUE,
                content TEXT NOT NULL,
                title TEXT,
                category TEXT,
                source TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # SQLite FTS5 for full-text search (optional speedup)
        try:
            cursor.execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts 
                USING fts5(doc_id, content, title, category)
            """)
        except Exception as e:
            logger.warning(f"FTS5 not supported: {e}. Falling back to standard query.")

        self.conn.commit()
    
    def load_knowledge_base(self, knowledge_dir: str = "data/knowledge_base"):
        """
        Load JSON files from knowledge base directory.
        Only runs once or when knowledge base is updated.
        """
        cursor = self.conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM documents")
        existing_count = cursor.fetchone()[0]
        
        # Always rebuild index if documents exist, but verify file changes (simplified here)
        # For now, if DB has docs, we just load them into memory. Real implementation might check hashes.
        if existing_count > 0:
            logger.info(f"Knowledge base already loaded ({existing_count} docs)")
            self._build_tfidf_index()
            # Still check for new files could be added here
            return
        
        knowledge_path = Path(knowledge_dir)
        if not knowledge_path.exists():
            # If path is relative, try making it absolute based on current file location
            # assuming services/lightweight_rag.py -> ../data/knowledge_base
            base_dir = Path(__file__).parent.parent
            knowledge_path = base_dir / knowledge_dir
            
            if not knowledge_path.exists():
                logger.warning(f"Knowledge base directory not found: {knowledge_path}")
                return
        
        documents_added = 0
        
        for json_file in knowledge_path.glob("*.json"):
            try:
                with open(json_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                category = data.get("category", "general")
                
                for idx, item in enumerate(data.get("items", [])):
                    doc_id = f"{json_file.stem}_{idx}"
                    content = item.get("content", "")
                    title = item.get("title", "")
                    
                    # Insert into SQLite
                    cursor.execute("""
                        INSERT OR IGNORE INTO documents 
                        (doc_id, content, title, category, source)
                        VALUES (?, ?, ?, ?, ?)
                    """, (doc_id, content, title, category, json_file.stem))
                    
                    # Insert into FTS table
                    try:
                        cursor.execute("""
                            INSERT OR IGNORE INTO documents_fts 
                            (doc_id, content, title, category)
                            VALUES (?, ?, ?, ?)
                        """, (doc_id, content, title, category))
                    except:
                        pass
                    
                    documents_added += 1
                
                self.conn.commit()
                logger.info(f"Loaded {json_file.name}: {len(data.get('items', []))} items")
            
            except Exception as e:
                logger.error(f"Error loading {json_file}: {e}")
        
        logger.info(f"Knowledge base loaded: {documents_added} documents")
        
        # Build TF-IDF index
        self._build_tfidf_index()
    
    def _build_tfidf_index(self):
        """Build TF-IDF vectors for fast similarity search"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT doc_id, content, title FROM documents ORDER BY id")
        
        self.documents = []
        texts = []
        
        for row in cursor.fetchall():
            doc_id, content, title = row
            # Combine title and content for better matching
            text = f"{title}. {content}"
            self.documents.append({
                "doc_id": doc_id,
                "content": content,
                "title": title
            })
            texts.append(text)
        
        if not texts:
            logger.warning("No documents to index")
            return
        
        # Create TF-IDF vectors (very fast, <100ms for 1000 docs)
        self.vectorizer = TfidfVectorizer(
            max_features=1000,  # Limit features for speed
            stop_words='english',
            ngram_range=(1, 2)  # Unigrams + bigrams
        )
        
        self.document_vectors = self.vectorizer.fit_transform(texts)
        logger.info(f"TF-IDF index built: {len(texts)} documents")
    
    def search(self, query: str, top_k: int = 3) -> List[Dict]:
        """
        Search for most relevant documents using TF-IDF similarity.
        
        Args:
            query: User's question
            top_k: Number of results to return
            
        Returns:
            List of dicts with 'content', 'title', 'category', 'score'
        """
        if not self.vectorizer or not self.documents:
            logger.warning("Index not built yet")
            return []
        
        # Vectorize query
        try:
            query_vector = self.vectorizer.transform([query])
            
            # Compute cosine similarity
            similarities = cosine_similarity(query_vector, self.document_vectors)[0]
            
            # Get top K results
            top_indices = np.argsort(similarities)[-top_k:][::-1]
            
            results = []
            for idx in top_indices:
                if similarities[idx] > 0.1:  # Minimum relevance threshold
                    doc = self.documents[idx]
                    results.append({
                        "content": doc["content"],
                        "title": doc["title"],
                        "doc_id": doc["doc_id"],
                        "score": float(similarities[idx])
                    })
            
            return results
        except Exception as e:
            logger.error(f"Error during TF-IDF search: {e}")
            return []
    
    def hybrid_search(self, query: str, top_k: int = 3) -> List[Dict]:
        """
        Hybrid search: TF-IDF + SQLite FTS5 for better results.
        Falls back to TF-IDF if FTS fails.
        """
        try:
            # Try FTS5 first (fast keyword search)
            cursor = self.conn.cursor()
            cursor.execute("""
                SELECT doc_id, content, title, rank
                FROM documents_fts
                WHERE documents_fts MATCH ?
                ORDER BY rank
                LIMIT ?
            """, (query, top_k))
            
            fts_results = cursor.fetchall()
            
            if fts_results:
                return [
                    {
                        "doc_id": row[0],
                        "content": row[1],
                        "title": row[2],
                        "score": 1.0 - (row[3] * 0.1)  # Convert rank to score
                    }
                    for row in fts_results
                ]
        except Exception as e:
            # logger.warning(f"FTS search failed or not supported, using TF-IDF: {e}")
            pass
        
        # Fallback to TF-IDF
        return self.search(query, top_k)
    
    def add_document(self, content: str, title: str, category: str = "user_added"):
        """Add a single document at runtime"""
        cursor = self.conn.cursor()
        doc_id = f"user_{category}_{cursor.lastrowid}"
        
        # Check if source column exists, if not add it (migration support)
        # For new installs, create_tables handles it.
        
        cursor.execute("""
            INSERT INTO documents (doc_id, content, title, category, source)
            VALUES (?, ?, ?, ?, 'user_input')
        """, (doc_id, content, title, category))
        
        try:
            cursor.execute("""
                INSERT INTO documents_fts (doc_id, content, title, category)
                VALUES (?, ?, ?, ?)
            """, (doc_id, content, title, category))
        except:
            pass
        
        self.conn.commit()
        
        # Rebuild index (lightweight operation)
        self._build_tfidf_index()
        
        logger.info(f"Added document: {title}")

# Global instance
rag = LightweightRAG()

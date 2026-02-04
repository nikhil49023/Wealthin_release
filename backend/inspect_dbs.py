import sqlite3
import os

def inspect_db(name, path):
    print(f"\n{'='*20} {name} {'='*20}")
    if not os.path.exists(path):
        print(f"Database not found at: {path}")
        return

    try:
        conn = sqlite3.connect(path)
        cursor = conn.cursor()
        
        # Get list of tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()
        
        if not tables:
            print("No tables found.")
        
        for table in tables:
            table_name = table[0]
            if table_name == 'sqlite_sequence':
                continue
                
            print(f"\nTable: {table_name}")
            
            # Get columns
            cursor.execute(f"PRAGMA table_info({table_name})")
            columns = cursor.fetchall()
            col_names = [col[1] for col in columns]
            print(f"Columns: {', '.join(col_names)}")
            
            # Get row count
            cursor.execute(f"SELECT count(*) FROM {table_name}")
            count = cursor.fetchone()[0]
            print(f"Row Count: {count}")
            
            # Show first 3 rows
            if count > 0:
                print("First 3 rows:")
                cursor.execute(f"SELECT * FROM {table_name} LIMIT 3")
                rows = cursor.fetchall()
                for row in rows:
                    print(f"  {row}")

        conn.close()
    except Exception as e:
        print(f"Error inspecting {name}: {e}")

if __name__ == "__main__":
    inspect_db("Transactions DB", "transactions.db")
    inspect_db("Planning DB", "planning.db")

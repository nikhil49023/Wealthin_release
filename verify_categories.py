import sqlite3
import os

DB_PATH = "backend/transactions.db"

def check_categories():
    if not os.path.exists(DB_PATH):
        print("DB not found.")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    print("\n--- Category Breakdown ---")
    cursor.execute("SELECT category, COUNT(*), SUM(amount) FROM transactions GROUP BY category ORDER BY SUM(amount) DESC")
    rows = cursor.fetchall()
    
    for row in rows:
        cat, count, total_amount = row
        print(f"{cat:<15} | Count: {count:<4} | Total: ₹{total_amount:,.2f}")

    print("\n--- Food Transactions (Sample) ---")
    cursor.execute("SELECT date, description, amount FROM transactions WHERE category = 'Food' LIMIT 5")
    food_rows = cursor.fetchall()
    if food_rows:
        for row in food_rows:
            print(f"{row[0]} | {row[1]} | ₹{row[2]}")
    else:
        print("No Food transactions found (maybe none in the PDF?)")

    conn.close()

if __name__ == "__main__":
    check_categories()

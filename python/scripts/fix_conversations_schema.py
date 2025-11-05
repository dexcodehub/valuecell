import sqlite3
from pathlib import Path

from valuecell.utils import resolve_db_path


def ensure_columns(conn: sqlite3.Connection, table: str, columns: dict) -> None:
    cur = conn.execute(f"PRAGMA table_info({table})")
    existing = {row[1] for row in cur.fetchall()}
    for name, ddl in columns.items():
        if name not in existing:
            conn.execute(f"ALTER TABLE {table} ADD COLUMN {ddl}")


def main() -> None:
    db_path = Path(resolve_db_path())
    conn = sqlite3.connect(db_path)
    try:
        # conversations: add agent_name, status
        ensure_columns(
            conn,
            "conversations",
            {
                "agent_name": "agent_name TEXT",
                "status": "status TEXT DEFAULT 'active'",
            },
        )

        # conversation_items: add agent_name, metadata
        ensure_columns(
            conn,
            "conversation_items",
            {
                "agent_name": "agent_name TEXT",
                "metadata": "metadata TEXT",
            },
        )

        conn.commit()
        print("Schema fix completed successfully.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
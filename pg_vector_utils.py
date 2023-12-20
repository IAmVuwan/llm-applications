import os
import psycopg2

# Set up
db_connection_string = os.environ.get("DB_CONNECTION_STRING")
migration_fp = os.environ.get("MIGRATION_FP")
sql_dump_fp = os.environ.get("SQL_DUMP_FP")


def check_connection():
    try:
        with psycopg2.connect(db_connection_string) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1;")
        print("Connection successful.")
    except psycopg2.OperationalError as e:
        print(f"Error: Unable to connect to the database. {e}")
        exit(1)


def drop_table():
    with psycopg2.connect(db_connection_string) as connection:
        with connection.cursor() as cursor:
            cursor.execute("DROP TABLE IF EXISTS document;")
            print("Table dropped.")


def run_migration():
    with psycopg2.connect(db_connection_string) as connection:
        with connection.cursor() as cursor:
            with open(migration_fp, "r") as migration_file:
                cursor.execute(migration_file.read())
            print("Migration script run.")


def load_sql_dump():
    with psycopg2.connect(db_connection_string) as connection:
        with connection.cursor() as cursor:
            with open(sql_dump_fp, "r") as sql_dump_file:
                cursor.execute(sql_dump_file.read())
            print("Data loaded.")


def query_number_of_rows():
    with psycopg2.connect(db_connection_string) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT count(*) FROM document;")
            num_rows = cursor.fetchone()[0]
            print(f"Number of rows in 'document' table: {num_rows}")

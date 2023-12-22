import sys
import pyodbc

def connection_string(database: str):
    driver = "ODBC Driver 18 for SQL Server"
    server, username, password = sys.argv[1:]

    return ";".join([
        f"DRIVER={driver}",
        f"SERVER={server}",
        f"DATABASE={database}",
        f"UID={username}",
        f"PWD={password}",
        "TrustServerCertificate=yes",
    ])

def execute_files(connection, files):
    queries = [(file, open(file, 'r').read()) for file in files]
    for (file, query) in queries:
        print("Executing file " + file + "...", end=" ")
        for query in filter(None, query.split("\nGO\n", )):
            with connection.cursor() as cursor:
                cursor.execute(query)
                cursor.commit()
        print("Success")

if __name__ == "__main__":
    try:
        print("Connecting to master database...", end=" ")
        with pyodbc.connect(connection_string("master"), autocommit=True) as connection:
            print("Success")
            execute_files(connection, ["database.sql"])

        print("Connecting to Supermarket database...", end=" ")
        with pyodbc.connect(connection_string("Supermarket")) as connection:
            print("Success")
            execute_files(
                connection,
                files = [
                    "structure.sql",
                    "users.sql",
                    "data.sql",
                ],
            )

        print("All done! Exiting...")
    except Exception as e:
        print(f"Error: {e}")

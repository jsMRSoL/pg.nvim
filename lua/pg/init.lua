local postgres_password = os.getenv('LSJ_PG_DATABASE_URL_LOCAL')
local sql_script = "imaginary_file.sql"
local cmd = "psql -d " .. postgres_password .. " -f " .. sql_script
print(cmd)

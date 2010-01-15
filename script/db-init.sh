#!/bin/sh

test_parser="$(pg_config --sharedir)/contrib/test_parser.sql"
[ ! -e "${test_parser}" ] && printf "%s\n%s\n" "Contrib module test_parser is not installed or pg_config is not properly installed." "Stopping." && exit 1
printf "%s: " "Danbooru database name"; read databasename;
printf "%s: " "Database superuser username (default: postgres)"; read username;

echo "Creating parser test_parser for database ${databasename}..."
echo "DROP TEXT SEARCH PARSER IF EXISTS testparser;" | psql "$@" -U "${username:-postgres}" "${databasename}" || exit 1
psql "$@" -U "${username:-postgres}" -f "${test_parser}" "${databasename}" || exit 1
echo "Done."
echo

echo "Creating custom functions for database ${databasename}..."
echo "CREATE OR REPLACE FUNCTION rlike(text, text) RETURNS bool AS 'SELECT \$2 LIKE \$1' LANGUAGE sql STRICT IMMUTABLE;
DROP OPERATOR IF EXISTS ~~~ (text, text);
CREATE OPERATOR ~~~ (procedure = rlike, leftarg = text, rightarg = text, commutator = ~~);" | psql "$@" -U "${username:-postgres}" "${databasename}" || exit 1
echo "Done."



EXTENSION    	= ast_postgis
EXTVERSION   	= $(shell grep default_version $(EXTENSION).control | \
               sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")
DOCS 				= $(wildcard doc/*)
# TESTS        = $(wildcard test/sql/*.sql)
# MODULES      = $(patsubst %.c,%,$(wildcard src/*.c))
REGRESS      	= $(patsubst test/sql/%.sql,%,$(TESTS))
REGRESS_OPTS 	= --inputdir=test
PG_CONFIG 		= pg_config

all: sql/$(EXTENSION)--$(EXTVERSION).sql

sql/$(EXTENSION)--$(EXTVERSION).sql: $(strip sql/tables.sql \
		sql/types.sql \
		sql/type_functions.sql \
		sql/utils.sql \
		sql/domain_functions.sql \
		sql/domains.sql \
		sql/relationship_triggers.sql \
		sql/event_triggers.sql \
		sql/consistency_functions.sql \
	)
	cat $^ > $@

DATA 				= sql/$(EXTENSION)--$(EXTVERSION).sql
EXTRA_CLEAN		= sql/$(EXTENSION)--$(EXTVERSION).sql
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

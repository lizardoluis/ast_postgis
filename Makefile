EXTENSION    = postgis_omtg
EXTVERSION   = $(shell grep default_version $(EXTENSION).control | \
               sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")

DATA         = $(filter-out $(wildcard sql/*--*.sql),$(wildcard sql/*.sql))
TESTS        = $(wildcard test/sql/*.sql)
REGRESS      = $(patsubst test/sql/%.sql,%,$(TESTS))
REGRESS_OPTS = --inputdir=test
DOCS         = $(wildcard doc/*.md)
MODULES      = $(patsubst %.c,%,$(wildcard src/*.c))
PG_CONFIG    = pg_config
PG91         = $(shell $(PG_CONFIG) --version | grep -qE " 8\\.| 9\\.0" && echo no || echo yes)

ifeq ($(PG91),yes)
all: sql/$(EXTENSION)--$(EXTVERSION).sql

sql/$(EXTENSION)--$(EXTVERSION).sql: $(strip sql/definitions/types.sql \
		sql/functions/utils.sql \
		sql/functions/domains_triggers.sql \
		sql/functions/validate_triggers.sql \
		sql/functions/relationship_triggers.sql \
		sql/definitions/eventtriggers.sql \
		sql/definitions/tables.sql \
		sql/definitions/types.sql \
		sql/definitions/domains.sql \
		sql/functions/consistency_check.sql \
	)
	cat $^ > $@

DATA = $(wildcard sql/*--*.sql) sql/$(EXTENSION)--$(EXTVERSION).sql
EXTRA_CLEAN = sql/$(EXTENSION)--$(EXTVERSION).sql
endif

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

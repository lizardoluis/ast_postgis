FROM camptocamp/postgis:9.5


WORKDIR /postgis_omtg
COPY . /postgis_omtg/
COPY 01-ast_postgis.sql /docker-entrypoint-initdb.d/

RUN printf "deb http://archive.debian.org/debian/ jessie main\ndeb-src http://archive.debian.org/debian/ jessie main\ndeb http://security.debian.org jessie/updates main\ndeb-src http://security.debian.org jessie/updates main" > /etc/apt/sources.list \
    && apt-get update \
    && apt-get install --no-install-recommends -y make postgresql-server-dev-9.5 \
    && make \
    && make install \
    && apt-get remove -y --purge make postgresql-server-dev-9.5 \
    && apt-get autoremove -y \
    && apt-get clean -y

EXPOSE 5432

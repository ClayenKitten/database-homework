# Source:
# https://github.com/microsoft/mssql-docker/issues/681
# (Modified)

FROM mcr.microsoft.com/mssql/server:2019-CU9-ubuntu-16.04

WORKDIR /
USER root

RUN apt-get -y update && \
    apt-get install -yq curl apt-transport-https && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/16.04/mssql-server-2019.list | tee /etc/apt/sources.list.d/mssql-server.list && \
    apt-get update && \
    apt-get install -y mssql-server-fts && \
    apt-get clean && \ 
    rm -rf /var/lib/apt/lists

CMD /opt/mssql/bin/sqlservr

FROM python:3.8-bullseye

WORKDIR /

ADD --chmod=644 https://packages.microsoft.com/keys/microsoft.asc /etc/apt/trusted.gpg.d/microsoft.asc
ADD --chmod=644 https://packages.microsoft.com/config/debian/11/prod.list /etc/apt/sources.list.d/mssql-release.list

RUN apt-get update && apt-get install -y unixodbc-dev
RUN apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql18

RUN pip install --no-cache-dir pyodbc

COPY setup/setup.py /
COPY src/*.sql /

CMD python -u setup.py db sa ${SA_PASSWORD}

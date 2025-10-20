# InterSystems IRIS Dockerfile for iris102 demo
FROM intersystemsdc/irishealth-community:2024.3

# Switch to root for setup
USER root

# Set working directory
WORKDIR /opt/irisapp

# Create necessary directories
RUN mkdir -p /opt/irisapp/src \
    && mkdir -p /data/IN \
    && mkdir -p /data/OUT \
    && mkdir -p /data/LOG \
    && mkdir -p /etc/odbc \
    && mkdir -p /opt/irisapp/odbc \
    && chmod -R 755 /data

# Copy source files
COPY src/ /opt/irisapp/src/

# Copy installer script
COPY Installer.cls /opt/irisapp/

# Copy ODBC configuration
COPY odbc/odbcinst.ini /opt/irisapp/odbc/odbcinst.ini
COPY odbc/odbc.ini /opt/irisapp/odbc/odbc.ini

# Set ownership and permissions
RUN chown -R irisowner:irisowner /opt/irisapp \
    && chown -R irisowner:irisowner /data

# Switch back to iris user
USER irisowner

# Environment variables for IRIS
ENV IRIS_PROJECT_PATH=/opt/irisapp/src
ENV IRIS_NAMESPACE=DEMO
ENV ODBCINI=/etc/odbc.ini
ENV ODBCSYSINI=/etc

# Copy and set up the IRIS initialization script
COPY --chown=irisowner:irisowner iris.script /tmp/iris.script

# Make the script executable and set as startup
USER root
RUN chmod +x /tmp/iris.script

# Install ODBC drivers and move configs into place
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-11-jre-headless \
    odbcinst \
    unixodbc \
    odbc-postgresql \
    odbc-mariadb \
    libpostgresql-jdbc-java \
    libmariadb-java \
    && rm -rf /var/lib/apt/lists/* \
    && cp /opt/irisapp/odbc/odbcinst.ini /etc/odbcinst.ini \
    && cp /opt/irisapp/odbc/odbc.ini /etc/odbc.ini \
        # Adjust driver library paths for current architecture (ARM64 vs x86_64)
        && if [ -d /usr/lib/aarch64-linux-gnu/odbc ]; then \
                 sed -i 's|/usr/lib/x86_64-linux-gnu/odbc|/usr/lib/aarch64-linux-gnu/odbc|g' /etc/odbcinst.ini; \
             fi \
    && chmod 644 /etc/odbcinst.ini /etc/odbc.ini \
    && mkdir -p /opt/irisapp/jdbc \
    && bash -lc 'set -e; for f in /usr/share/java/postgresql*.jar; do cp "$f" /opt/irisapp/jdbc/postgresql.jar; break; done' \
    && bash -lc 'set -e; for f in /usr/share/java/mariadb-java-client*.jar /usr/share/java/mariadb*.jar; do if [ -f "$f" ]; then cp "$f" /opt/irisapp/jdbc/mariadb-java-client.jar; break; fi; done' \
    && chown -R irisowner:irisowner /opt/irisapp/jdbc \
    && chmod 644 /opt/irisapp/jdbc/*.jar || true

# Switch back to irisowner
USER irisowner
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH
ENV JDBC_CLASSPATH=/opt/irisapp/jdbc/postgresql.jar:/opt/irisapp/jdbc/mariadb-java-client.jar
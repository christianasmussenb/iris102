# InterSystems IRIS Dockerfile for iris102 demo
FROM intersystemsdc/iris-community:latest

# Switch to root for setup
USER root

# Set working directory
WORKDIR /opt/irisapp

# Create necessary directories
RUN mkdir -p /opt/irisapp/src \
    && mkdir -p /data/IN \
    && mkdir -p /data/OUT \
    && mkdir -p /data/LOG \
    && chmod -R 755 /data

# Copy source files
COPY src/ /opt/irisapp/src/

# Copy installer script
COPY Installer.cls /opt/irisapp/

# Set ownership and permissions
RUN chown -R irisowner:irisowner /opt/irisapp \
    && chown -R irisowner:irisowner /data

# Switch back to iris user
USER irisowner

# Environment variables for IRIS
ENV IRIS_PROJECT_PATH=/opt/irisapp/src
ENV IRIS_NAMESPACE=DEMO

# Copy and set up the IRIS initialization script
COPY --chown=irisowner:irisowner iris.script /tmp/iris.script

# Make the script executable and set as startup
USER root
RUN chmod +x /tmp/iris.script

# Switch back to irisowner
USER irisowner
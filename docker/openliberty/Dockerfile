# =============================================================================
# Open Liberty Application Layer
# =============================================================================
# This container runs the Java application on Open Liberty server.
# It connects to Azure Database for PostgreSQL (managed service).
#
# Build args:
#   WAR_FILE - path to your application WAR file (default: app.war)
# =============================================================================

FROM icr.io/appcafe/open-liberty:kernel-slim-java17-openj9-ubi

# Switch to root for installation
USER root

# Install PostgreSQL JDBC driver and required features
ARG JDBC_POSTGRES_VERSION=42.7.3
RUN curl -fsSL -o /opt/ol/wlp/lib/postgresql-jdbc.jar \
    "https://jdbc.postgresql.org/download/postgresql-${JDBC_POSTGRES_VERSION}.jar"

# Copy server configuration
COPY --chown=1001:0 server.xml /config/server.xml
COPY --chown=1001:0 bootstrap.properties /config/bootstrap.properties
COPY --chown=1001:0 jvm.options /config/jvm.options

# Copy application WAR/EAR file
# Replace 'app.war' with your actual application artifact
ARG WAR_FILE=app.war
COPY --chown=1001:0 ${WAR_FILE} /config/apps/app.war

# Switch back to non-root user
USER 1001

# Install Liberty features defined in server.xml
RUN features.sh

# Perform SCC (Shared Class Cache) optimization for faster startup
RUN configure.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9080/health || exit 1

EXPOSE 9080 9443

CMD ["/opt/ol/wlp/bin/server", "run", "defaultServer"]

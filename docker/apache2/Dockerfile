# =============================================================================
# Apache2 Web Layer - Reverse Proxy to Open Liberty App Layer
# =============================================================================
# This container serves as the front-end web layer, handling:
#   - Static content serving
#   - Reverse proxy to Open Liberty backend
#   - SSL termination (optional, can also be handled at Ingress level)
#   - Request logging and health checks
# =============================================================================

FROM httpd:2.4-alpine

# Install required Apache modules dependencies
RUN apk add --no-cache \
    curl \
    && rm -rf /var/cache/apk/*

# Enable required Apache modules for reverse proxying
RUN sed -i \
    -e 's/#LoadModule proxy_module/LoadModule proxy_module/' \
    -e 's/#LoadModule proxy_http_module/LoadModule proxy_http_module/' \
    -e 's/#LoadModule proxy_balancer_module/LoadModule proxy_balancer_module/' \
    -e 's/#LoadModule slotmem_shm_module/LoadModule slotmem_shm_module/' \
    -e 's/#LoadModule rewrite_module/LoadModule rewrite_module/' \
    -e 's/#LoadModule headers_module/LoadModule headers_module/' \
    /usr/local/apache2/conf/httpd.conf

# Copy custom Apache configuration
COPY httpd-custom.conf /usr/local/apache2/conf/extra/httpd-custom.conf
COPY vhost.conf /usr/local/apache2/conf/extra/vhost.conf

# Include custom configs in main httpd.conf
RUN echo "" >> /usr/local/apache2/conf/httpd.conf && \
    echo "# Custom configuration" >> /usr/local/apache2/conf/httpd.conf && \
    echo "Include conf/extra/httpd-custom.conf" >> /usr/local/apache2/conf/httpd.conf && \
    echo "Include conf/extra/vhost.conf" >> /usr/local/apache2/conf/httpd.conf

# Copy static content (if any) from your VM
# Uncomment and adjust the path to your static files
# COPY ./static/ /usr/local/apache2/htdocs/

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

EXPOSE 80

CMD ["httpd-foreground"]

FROM quay.io/keycloak/keycloak:23.0.7 as builder

# Enable health and metrics support
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

WORKDIR /opt/keycloak

# Copying keycloak-metrics-spi provider
COPY keycloak-metrics-spi.jar /opt/keycloak/providers/

RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:23.0.7
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# Copying keycloak-metrics-spi provider
COPY --from=builder /opt/keycloak/providers/keycloak-metrics-spi.jar /opt/keycloak/providers/

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]

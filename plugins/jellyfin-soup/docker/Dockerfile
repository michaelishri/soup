# Local Jellyfin 10.11 with Soup Auth plugin baked in.
# Build from plugins/jellyfin-soup:
#   ./scripts/stage-plugin.sh
#   docker build -f docker/Dockerfile -t soup-jellyfin:local .
ARG JELLYFIN_TAG=10.11.5
FROM jellyfin/jellyfin:${JELLYFIN_TAG}

# Path without spaces (classic builder); entrypoint installs as "Soup Auth".
COPY docker/plugin/ /opt/soup/plugins/SoupAuth/
COPY docker/entrypoint.sh /entrypoint-soup.sh

USER root
RUN chmod +x /entrypoint-soup.sh

ENTRYPOINT ["/entrypoint-soup.sh"]

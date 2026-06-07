# ---------------------------------------------
# Overleaf Community Edition (overleaf/overleaf)
# ---------------------------------------------

ARG OVERLEAF_BASE_TAG=fred1653/sharelatex-base:latest
FROM $OVERLEAF_BASE_TAG

ARG TEXDOCK_VERSION=dev
LABEL org.opencontainers.image.version="${TEXDOCK_VERSION}" \
      texdock.version="${TEXDOCK_VERSION}"

WORKDIR /overleaf

# Add required source files for yarn/npm install
# ----------------------------------------------
COPY --parents libraries/*/package.json .yarn/patches/ services/*/package.json tools/migrations/ package.json yarn.lock .yarnrc.yml /overleaf/
COPY server-ce/genScript.js server-ce/services.js /overleaf/

# Corepack / Yarn
# ---------------
ENV PATH="/overleaf/node_modules/.bin:$PATH"
ENV COREPACK_HOME=/opt/corepack

RUN corepack enable && corepack install -g yarn@4.14.1
RUN yarn config set npmRegistryServer https://registry.npmmirror.com
ENV COREPACK_ENABLE_NETWORK=0

# Avoid old npm/git dependencies resolving GitHub URLs through SSH.
# ----------------------------------------------------------------
RUN git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" \
 && git config --global url."https://github.com/".insteadOf "git@github.com:" \
 && git config --global url."https://github.com/".insteadOf "git+ssh://git@github.com/"

# Install dependencies
# --------------------
# genScript install 会生成 npm install --omit=dev，这是正常的。
RUN --mount=type=cache,target=/root/.cache \
    --mount=type=cache,target=/root/.npm,id=server-ce-npm-cache \
    --mount=type=cache,target=/root/.yarn/berry/cache,id=server-ce-yarn-cache \
    --mount=type=cache,target=/usr/local/share/.cache/yarn,id=server-ce-yarn-fallback-cache \
    --mount=type=tmpfs,target=/tmp \
    set -eux; \
    node genScript install > /tmp/install.sh; \
    bash -x /tmp/install.sh; \
    rm -f /tmp/install.sh

# Add actual source files
# -----------------------
COPY --parents libraries/ services/ tools/migrations/ /overleaf/

# Patch old Pug syntax incompatible with current pug precompile.
# --------------------------------------------------------------
RUN set -eux; \
    test -f /overleaf/services/web/app/views/user/restricted.pug; \
    sed -i 's#a(href="/").material-symbols(aria-hidden="true")#a.material-symbols(href="/", aria-hidden="true")#g' \
      /overleaf/services/web/app/views/user/restricted.pug

# Add local build patch scripts
# -----------------------------
COPY scripts/patch-pdfjs-worker-wasm.sh /usr/local/bin/patch-pdfjs-worker-wasm.sh
RUN chmod +x /usr/local/bin/patch-pdfjs-worker-wasm.sh

# Compile frontend/assets
# -----------------------
RUN --mount=type=cache,target=/root/.cache \
    --mount=type=cache,target=/root/.npm,id=server-ce-npm-cache \
    --mount=type=cache,target=/root/.yarn/berry/cache,id=server-ce-yarn-cache \
    --mount=type=cache,target=/usr/local/share/.cache/yarn,id=server-ce-yarn-fallback-cache \
    --mount=type=cache,target=/overleaf/services/web/node_modules/.cache,id=server-ce-webpack-cache \
    --mount=type=tmpfs,target=/tmp \
    set -eux; \
    node genScript compile > /tmp/compile.sh; \
    sed -i 's#npm run webpack:production#patch-pdfjs-worker-wasm.sh \&\& npm run webpack:production#g' /tmp/compile.sh; \
    bash -x /tmp/compile.sh; \
    rm -f /tmp/compile.sh

# Copy runit service startup scripts to its location
# --------------------------------------------------
ADD server-ce/runit /etc/service

# Copy runit global settings to its location
# ------------------------------------------
ADD server-ce/config/env.sh /etc/overleaf/env.sh

# Configure nginx
# ---------------
ADD server-ce/nginx/nginx.conf.template /etc/nginx/templates/nginx.conf.template
ADD server-ce/nginx/overleaf.conf /etc/nginx/sites-enabled/overleaf.conf
ADD server-ce/nginx/clsi-nginx.conf /etc/nginx/sites-enabled/clsi-nginx.conf

# Configure log rotation
# ----------------------
ADD server-ce/logrotate/overleaf /etc/logrotate.d/overleaf
RUN chmod 644 /etc/logrotate.d/overleaf

# Configure cron tasks
# --------------------
ADD server-ce/cron /overleaf/cron
ADD server-ce/config/crontab-history /etc/cron.d/crontab-history
RUN chmod 600 /etc/cron.d/crontab-history
ADD server-ce/config/crontab-deletion /etc/cron.d/crontab-deletion
RUN chmod 600 /etc/cron.d/crontab-deletion

# Copy Phusion Image startup and shutdown scripts to their locations
# ------------------------------------------------------------------
COPY server-ce/init_scripts/ /etc/my_init.d/
COPY server-ce/init_preshutdown_scripts/ /etc/my_init.pre_shutdown.d/

# Copy app settings files
# -----------------------
COPY server-ce/config/settings.js /etc/overleaf/settings.js

# Copy history-v1 files
# ---------------------
COPY server-ce/config/production.json /overleaf/services/history-v1/config/production.json
COPY server-ce/config/custom-environment-variables.json /overleaf/services/history-v1/config/custom-environment-variables.json

# Copy grunt thin wrapper
# -----------------------
ADD server-ce/bin/grunt /usr/local/bin/grunt
RUN chmod +x /usr/local/bin/grunt

# Copy history helper scripts
# ---------------------------
ADD server-ce/bin/flush-history-queues /overleaf/bin/flush-history-queues
RUN chmod +x /overleaf/bin/flush-history-queues
ADD server-ce/bin/force-history-resyncs /overleaf/bin/force-history-resyncs
RUN chmod +x /overleaf/bin/force-history-resyncs

# Copy Latexmkrc
# --------------
COPY server-ce/config/latexmkrc /usr/local/share/latexmk/LatexMk

# File that controls open|closed status of the site
# -------------------------------------------------
ENV SITE_MAINTENANCE_FILE="/etc/overleaf/site_status"
RUN touch $SITE_MAINTENANCE_FILE

# Set Environment Variables
# -------------------------
ENV OVERLEAF_CONFIG=/etc/overleaf/settings.js

ENV WEB_API_USER="overleaf"
ENV ADMIN_PRIVILEGE_AVAILABLE="true"

ENV OVERLEAF_APP_NAME="Overleaf Community Edition"

ENV OPTIMISE_PDF="true"

# Phusion Image timeouts before sending SIGKILL to processes
# ----------------------------------------------------------
ENV KILL_PROCESS_TIMEOUT=55
ENV KILL_ALL_PROCESSES_TIMEOUT=55
ENV GRACEFUL_SHUTDOWN_DELAY_SECONDS=1

ENV NODE_ENV="production"
ENV LOG_LEVEL="info"

EXPOSE 80

ENTRYPOINT ["/sbin/my_init"]

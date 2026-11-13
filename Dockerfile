# JupyterLab + R kernel, multi-architecture (linux/amd64 and linux/arm64).
# The base image rocker/r-ver is published for both architectures, so
# Apple Silicon Macs run it natively (no emulation).
#
# R version and CRAN snapshot are fixed by the rocker tag (reproducible).
ARG R_VERSION=4.4.2
FROM rocker/r-ver:${R_VERSION}

ARG JUPYTERLAB_VERSION=4.2.5
ARG NB_USER=student
ARG NB_UID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8

# Python + JupyterLab in an isolated virtualenv
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip \
        libzmq3-dev libcurl4-openssl-dev libssl-dev libxml2-dev \
        git curl ca-certificates tini \
 && rm -rf /var/lib/apt/lists/* \
 && python3 -m venv "$VIRTUAL_ENV" \
 && pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir "jupyterlab==${JUPYTERLAB_VERSION}"

# R kernel for Jupyter (system-wide, so every user sees it)
RUN R -q -e 'install.packages("IRkernel")' \
 && R -q -e 'IRkernel::installspec(user = FALSE, name = "ir", displayname = "R")' \
 && R -q -e 'stopifnot(requireNamespace("IRkernel", quietly = TRUE))'

# Extra R packages for the course: add them here, e.g.
# RUN R -q -e 'install.packages(c("ggplot2", "dplyr"))'

# File browser shows the real container filesystem (root = /) and opens in
# /sharedFolder, so the path students see is the real one: /sharedFolder/...
# Only files saved under /sharedFolder are kept on the host.

# Non-root user. HOME is world-writable so the container also works when the
# run script starts it with the host UID (Linux) to keep file permissions right.
RUN useradd -m -s /bin/bash -u "${NB_UID}" "${NB_USER}" \
 && mkdir -p /sharedFolder \
 && chmod 1777 /home/${NB_USER} /sharedFolder

ENV HOME=/home/${NB_USER}
USER ${NB_UID}
WORKDIR /sharedFolder
EXPOSE 8888

ENTRYPOINT ["tini", "-g", "--"]
CMD ["jupyter", "lab", \
     "--ip=0.0.0.0", "--port=8888", "--no-browser", \
     "--ServerApp.root_dir=/", \
     "--ServerApp.preferred_dir=/sharedFolder", \
     "--IdentityProvider.token=", \
     "--ServerApp.allow_remote_access=True"]

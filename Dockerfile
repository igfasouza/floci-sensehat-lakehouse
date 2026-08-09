FROM quay.io/jupyter/all-spark-notebook:latest

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    i2c-tools \
    && rm -rf /var/lib/apt/lists/*

# Use the Adoptium Temurin API, which redirects to the current JDK 25 GA build.
# Override JDK_URL at build time to pin to a specific point release for full reproducibility.
ARG JDK_URL="https://api.adoptium.net/v3/binary/latest/25/ga/linux/aarch64/jdk/hotspot/normal/eclipse"
RUN curl -fsSL "${JDK_URL}" -o /tmp/jdk25.tar.gz \
    && mkdir -p /opt/jdk-25 \
    && tar -xzf /tmp/jdk25.tar.gz -C /opt/jdk-25 --strip-components=1 \
    && rm /tmp/jdk25.tar.gz \
    && /opt/jdk-25/bin/java -version

ENV JAVA_HOME=/opt/jdk-25
ENV PATH="${JAVA_HOME}/bin:${PATH}"

USER jovyan

RUN pip install --no-cache-dir jjava && \
    python -m jjava.install

WORKDIR /home/jovyan/work
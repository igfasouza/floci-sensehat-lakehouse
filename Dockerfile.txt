FROM quay.io/jupyter/all-spark-notebook:latest

USER root

RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
    i2c-tools \
    libgpiod2 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L -o /tmp/jdk25.tar.gz \
    https://download.java.net/java/GA/jdk25/latest/binaries/openjdk-25_linux-aarch64_bin.tar.gz \
    && mkdir -p /opt \
    && tar -xzf /tmp/jdk25.tar.gz -C /opt \
    && mv /opt/jdk-25* /opt/jdk-25 \
    && rm /tmp/jdk25.tar.gz

ENV JAVA_HOME=/opt/jdk-25
ENV PATH="${JAVA_HOME}/bin:${PATH}"

USER jovyan

RUN pip install --no-cache-dir jjava && \
    python -m jjava.install

WORKDIR /home/jovyan/work
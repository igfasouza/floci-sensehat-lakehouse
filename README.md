# Floci Lakehouse Demo with Raspberry Pi, Java 25, Spark and Sense HAT

This project demonstrates how to build a complete IoT Lakehouse running on a **Raspberry Pi 4 (8 GB)** using:

- Java 25
- Jupyter Notebook
- Apache Spark
- Raspberry Pi Sense HAT
- Pi4J Drivers
- Apache Parquet
- Apache Hudi
- Delta Lake
- Apache Iceberg
- Floci (S3-compatible Object Storage)

The notebook reads live sensor data from the Raspberry Pi Sense HAT, creates a Spark DataFrame, and writes the data to Floci using multiple Lakehouse table formats.

---

# Environment Used

- Raspberry Pi 4 (8 GB recommended)
- Raspberry Pi OS 64-bit
- Docker & Docker Compose
- Sense HAT installed
- I2C enabled

---

# docker-compose.yml

```yaml
services:
  floci:
    image: floci/floci:1.5.25
    container_name: floci
    platform: linux/arm64
    ports:
      - "4566:4566"
    volumes:
      - ./floci-data:/app/data

  jupyter:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: jupyter-java25-sensehat
    platform: linux/arm64
    depends_on:
      - floci
    ports:
      - "8888:8888"
      - "4040:4040"
    volumes:
      - ./notebooks:/home/jovyan/work
      - ./ivy-cache:/home/jovyan/.ivy2

    devices:
      - "/dev/i2c-1:/dev/i2c-1"
      - "/dev/fb0:/dev/fb0"

    privileged: true

    environment:
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
      - AWS_DEFAULT_REGION=us-east-1
      - AWS_ENDPOINT_URL=http://floci:4566
      - JAVA_HOME=/opt/jdk-25
      - PATH=/opt/jdk-25/bin:/usr/local/spark/bin:/opt/conda/bin:/usr/local/bin:/usr/bin:/bin

    command: >
      start-notebook.py
      --IdentityProvider.token=''
      --ServerApp.password=''
```

---

# Dockerfile

```dockerfile
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
```

---

# Build the Environment

Build and start all services:

```bash
docker compose up --build
```

---

# Create the S3 Buckets

Once Floci is running, create the buckets used by the notebook:

```bash
aws s3 mb s3://iot-raw --endpoint-url http://localhost:4566

aws s3 mb s3://iot-hudi --endpoint-url http://localhost:4566

aws s3 mb s3://iot-delta --endpoint-url http://localhost:4566

aws s3 mb s3://iot-iceberg --endpoint-url http://localhost:4566
```

---

# Open Jupyter

Open your browser:

```
http://<RASPBERRY_PI_IP>:8888
```

Then open:

```
notebooks/Floci_Java25_SenseHAT_Lakehouse_Demo.ipynb
```

---

# Sense HAT Access

The most important part of the Docker Compose configuration is giving the container access to the Raspberry Pi I2C bus.

```yaml
devices:
  - "/dev/i2c-1:/dev/i2c-1"

privileged: true
```

Without these settings, the Jupyter container will not be able to communicate with the Sense HAT over I2C.

If you also want to use the LED matrix, expose the framebuffer as well:

```yaml
devices:
  - "/dev/i2c-1:/dev/i2c-1"
  - "/dev/fb0:/dev/fb0"
```


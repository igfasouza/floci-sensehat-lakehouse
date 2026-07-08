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

---

# Notebooks

This repository contains two Java notebooks.

## 1. Sense HAT Lakehouse Demo

```text
notebooks/Floci_Java25_SenseHAT_Lakehouse_Demo.ipynb
```

This is the main notebook. It reads live sensor data from the Raspberry Pi Sense HAT and writes the data to Floci using multiple Lakehouse table formats.

The notebook demonstrates:

- Reading temperature, humidity and pressure from Sense HAT
- Using Java 25 inside Jupyter Notebook
- Creating a Spark DataFrame
- Writing and reading Apache Parquet
- Writing and reading Apache Hudi
- Writing and reading Delta Lake
- Writing and reading Apache Iceberg

The data is written to the following S3-compatible paths:

```text
s3://iot-raw/sensehat/temperature_parquet/
s3://iot-hudi/sensehat/temperature_hudi/
s3://iot-delta/sensehat/temperature_delta/
s3://iot-iceberg/warehouse/
```

Run this notebook first.

---

## 2. Athena + Glue External Tables Demo

```text
notebooks/Floci_Java25_Athena_Glue_External_Tables_Demo.ipynb
```

This second notebook assumes that the first notebook has already written the data to Floci.

It focuses on registering the generated data as external tables in a Glue-compatible catalog and querying those tables using Athena.

The notebook demonstrates:

- Creating a Glue database
- Registering external tables for Parquet, Hudi, Delta Lake and Iceberg
- Running `SELECT *` queries using Athena
- Printing query results directly from the Java notebook

The flow is:

```text
Data written by Notebook 1
        ↓
Floci S3-compatible storage
        ↓
Glue external tables
        ↓
Athena SELECT *
```

The notebook creates tables such as:

```text
iot.sensehat_parquet
iot.sensehat_hudi
iot.sensehat_delta
iot.sensehat_iceberg
```

For the most reliable local test, start with the Parquet table first. Hudi, Delta Lake and Iceberg may require table-format-specific support from the local Athena-compatible engine.

---

## Recommended Execution Order

Run the notebooks in this order:

```text
1. Floci_Java25_SenseHAT_Lakehouse_Demo.ipynb
2. Floci_Java25_Athena_Glue_External_Tables_Demo.ipynb
```

The first notebook creates the data.  
The second notebook registers and queries the data.

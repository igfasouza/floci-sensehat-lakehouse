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
    ports:
      - "4566:4566"
    volumes:
      - ./floci-data:/app/data

  jupyter:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: jupyter-java25-sensehat
    depends_on:
      - floci
    ports:
      - "8888:8888"
      - "4040:4040"
    volumes:
      - ./notebooks:/home/jovyan/work
      - ./ivy-cache:/home/jovyan/.ivy2
      - /dev/input:/dev/input      # Sense HAT joystick events
    devices:
      - "/dev/i2c-1:/dev/i2c-1"    # sensors + LED matrix
      - "/dev/fb0:/dev/fb0"        # LED matrix framebuffer
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

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    i2c-tools \
    && rm -rf /var/lib/apt/lists/*

# Adoptium Temurin JDK 25 (aarch64). Override JDK_URL at build time
# to pin to a specific point release.
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
```

---

# Build the Environment

Build and start all services:

```bash
docker compose up --build
```

---

# Create the S3 Buckets

The Lakehouse notebook (`02_SenseHAT_Lakehouse_Demo.ipynb`) creates its own buckets on startup, so you can skip this step. If you want to create them manually beforehand:

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

Then run the notebooks in numeric order — the filenames themselves indicate the order.

---

# Sense HAT Access

The Sense HAT talks to the Pi through three different kernel interfaces, so the container needs access to all of them:

```yaml
volumes:
  - /dev/input:/dev/input        # joystick events (evdev)
devices:
  - "/dev/i2c-1:/dev/i2c-1"      # sensors + LED matrix (I2C bus)
  - "/dev/fb0:/dev/fb0"          # LED matrix framebuffer
privileged: true
```

Symptoms if one is missing:

| Missing              | Symptom                                                     |
|----------------------|-------------------------------------------------------------|
| `/dev/i2c-1`         | All sensor reads fail — no HTS221 / LPS25H / LSM9DS1        |
| `/dev/fb0`           | LED matrix stays dark                                       |
| `/dev/input`         | `getEvents()` / `waitForEvent()` / joystick listeners fail  |

---

# Notebooks

This repository contains three Java notebooks, numbered in the order they should be run.

## 01. Sense HAT API Tour

```text
notebooks/01_SenseHAT_API_Tour.ipynb
```

A hands-on tour of the entire `com.pi4j.drivers.hat.raspberry.SenseHat` API — no Spark or Floci involved, just the sensor board. Great starting point to confirm your Sense HAT wiring works before moving on to the Lakehouse demo.

The notebook demonstrates:

- Environmental sensors: humidity (HTS221), pressure (LPS25H), temperature from both chips, light/colour (TCS3400)
- IMU: accelerometer, gyroscope, orientation (degrees and radians), magnetometer, compass heading, and `setImuConfig`
- LED matrix pixels: `clear`, `fill`, `setPixel`, `getPixel`, `setPixels` (1-D and 2-D), `getPixels`
- LED matrix orientation: rotation and horizontal/vertical flip
- LED matrix text: `showLetter` and `showMessage` with colours, scroll speed, and direction
- Direct access to the underlying `GraphicsDisplayDriver` / `GraphicsDisplay`
- Joystick in all three access modes: polling (`getEvents`), blocking (`waitForEvent`), and listener (`addJoystickListener`)
- The generic `getAllSensors()` list
- Proper lifecycle: `senseHat.close()` and `pi4j.shutdown()`

Reference for the underlying driver: [pi4j-drivers SenseHat.java](https://github.com/igfasouza/pi4j-drivers/blob/igfasouza/src/main/java/com/pi4j/drivers/hat/raspberry/SenseHat.java).

---

## 02. Sense HAT Lakehouse Demo

```text
notebooks/02_SenseHAT_Lakehouse_Demo.ipynb
```

The main lakehouse notebook. It reads live sensor data from the Sense HAT and writes it to Floci using multiple lakehouse table formats.

The notebook demonstrates:

- Reading temperature, humidity and pressure from the Sense HAT (temperature is averaged from both the humidity and pressure chips)
- Bootstrapping the required S3 buckets on Floci
- Using Java 25 inside Jupyter Notebook
- Building a Spark DataFrame from Java records via `Row` + `StructType`
- Writing and reading Apache Parquet
- Writing and reading Apache Hudi (partitioned by event date, composite record key)
- Writing and reading Delta Lake (plus generating the symlink-format manifest for Athena)
- Writing and reading Apache Iceberg (Hadoop catalog)

The data is written to the following S3-compatible paths:

```text
s3://iot-raw/sensehat/temperature_parquet/
s3://iot-hudi/sensehat/temperature_hudi/
s3://iot-delta/sensehat/temperature_delta/
s3://iot-iceberg/warehouse/default/temperature_iceberg/
```

---

## 03. Athena + Glue External Tables Demo

```text
notebooks/03_Athena_Glue_External_Tables_Demo.ipynb
```

Assumes notebook 02 has already written the data to Floci. It registers those datasets as external tables in a Glue-compatible catalog and queries them with Athena.

The notebook demonstrates:

- Creating a Glue database
- Registering external tables for Parquet, Hudi, Delta Lake and Iceberg (resolving the Iceberg `metadata_location` from `version-hint.text`, and pointing Delta at the symlink manifest produced by notebook 02)
- Running `SELECT *` and aggregation queries with Athena
- Printing query results directly from the Java notebook

The flow is:

```text
Notebook 02 writes data
        ↓
Floci S3-compatible storage
        ↓
Glue external tables (Notebook 03)
        ↓
Athena SELECT
```

The notebook creates tables such as:

```text
iot.sensehat_parquet
iot.sensehat_hudi
iot.sensehat_delta
iot.sensehat_iceberg
```

For the most reliable local test, start with the Parquet table. Hudi, Delta Lake and Iceberg may require table-format-specific support from the local Athena-compatible engine.

---

## Recommended Execution Order

The filenames already encode the order. Notebook 01 is optional — skip it if you already know your Sense HAT works.

```text
01_SenseHAT_API_Tour.ipynb              (optional — sanity check the HAT)
02_SenseHAT_Lakehouse_Demo.ipynb        (writes the data)
03_Athena_Glue_External_Tables_Demo.ipynb  (queries the data)
```

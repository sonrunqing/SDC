FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates xvfb xauth libgl1-mesa-dri libglx-mesa0 libx11-6 libx11-xcb1 \
    libxcursor1 libxinerama1 libxi6 libxrandr2 libasound2 libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /game
COPY ai/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
COPY . /game
ENV LIBGL_ALWAYS_SOFTWARE=1
RUN python ai/bootstrap.py
ENTRYPOINT ["python", "ai/mcp_server.py"]

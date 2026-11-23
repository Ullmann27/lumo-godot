FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 HOST=0.0.0.0 PORT=8765 LUMO_DATABASE_PATH=/data/lumo-kart.sqlite3
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --system --uid 10001 lumo && mkdir /data && chown lumo /data
COPY relay.py storage.py ./
USER 10001
EXPOSE 8765
VOLUME /data
CMD ["python", "relay.py"]

FROM python:alpine

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apk update && \
    apk upgrade && \
    apk add --no-cache ffmpeg && \
    pip install --no-cache-dir --upgrade pip==26.1.2 setuptools wheel

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY wsgi.py .
COPY templates ./templates
COPY static ./static

EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "8", "--timeout", "0", "wsgi:app"]

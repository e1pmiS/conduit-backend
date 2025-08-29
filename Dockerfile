FROM python:3.5.10-slim-buster

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=conduit.settings

WORKDIR /app

COPY requirements.txt .
RUN python -m pip install --upgrade "pip<21" "setuptools<50" "wheel<1" \
 && pip install -r requirements.txt 

COPY . .
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["/entrypoint.sh"]
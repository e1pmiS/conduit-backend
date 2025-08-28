#!/bin/sh
set -e

# ensure DB directory exists if using named volume
if [ -n "${DJANGO_DB_PATH}" ]; then
  mkdir -p "$(dirname "${DJANGO_DB_PATH}")"
fi

# Django settings
export DJANGO_SETTINGS_MODULE="${DJANGO_SETTINGS_MODULE:-conduit.settings}"

# Migrations and static
python manage.py migrate --noinput
python manage.py collectstatic --noinput || true

# Create admin only if missing (no password overwrite)
python - <<'PY'
import os, django
django.setup()
from django.contrib.auth import get_user_model
User = get_user_model()

email = os.environ.get('DJANGO_ADMIN_EMAIL')
username = os.environ.get('DJANGO_ADMIN_USERNAME') or 'admin'
password = os.environ.get('DJANGO_ADMIN_PASSWORD')

if email:
    try:
        u = User.objects.get(email=email)
        changed = False
        if not u.is_staff: u.is_staff=True; changed=True
        if not u.is_superuser: u.is_superuser=True; changed=True
        if changed: u.save(); print("admin user:", email, "| exists, flags updated")
        else: print("admin user:", email, "| exists, unchanged")
    except User.DoesNotExist:
        u = User(email=email)
        if hasattr(u,'username'): u.username = username
        if password: u.set_password(password)
        u.is_staff = True; u.is_superuser = True; u.save()
        print("admin user:", email, "| created")
else:
    print("admin bootstrap skipped: DJANGO_ADMIN_EMAIL not set")
PY

# Auto workers = 2*CPU + 1 (fallback 3)
WORKERS="$(python - <<'PY'
import multiprocessing as m
try: print(m.cpu_count()*2+1)
except: print(3)
PY
)"

# Start Gunicorn (production WSGI)
exec gunicorn conduit.wsgi:application --bind 0.0.0.0:8000 --workers "${WORKERS}"
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

# admin bootstrap via Django shell -c (no password overwrite if exists)
if [ -n "${DJANGO_ADMIN_EMAIL}" ]; then
  python manage.py shell -c "
import os
from django.contrib.auth import get_user_model
U = get_user_model()
e = os.environ.get('DJANGO_ADMIN_EMAIL')
u = os.environ.get('DJANGO_ADMIN_USERNAME') or 'admin'
p = os.environ.get('DJANGO_ADMIN_PASSWORD')

if not e:
    print('admin bootstrap skipped: no email'); raise SystemExit(0)

try:
    obj = U.objects.get(email=e)
    changed = False
    if not obj.is_staff: obj.is_staff = True; changed = True
    if not obj.is_superuser: obj.is_superuser = True; changed = True
    if changed: obj.save(); print('admin user:', e, '| exists, flags updated')
    else: print('admin user:', e, '| exists, unchanged')
except U.DoesNotExist:
    obj = U(email=e)
    if hasattr(obj, 'username'): obj.username = u
    if p: obj.set_password(p)
    obj.is_active = True
    obj.is_staff = True
    obj.is_superuser = True
    obj.save()
    print('admin user:', e, '| created')
"
else
  echo "admin bootstrap skipped: DJANGO_ADMIN_EMAIL not set"
fi

# start Gunicorn with SQLite-safe concurrency
WORKERS=1
THREADS=4    

exec gunicorn conduit.wsgi:application \
  --bind 0.0.0.0:8000 \
  --workers "$WORKERS" \
  --threads "$THREADS" \
  --timeout 120
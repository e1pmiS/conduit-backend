#!/bin/sh
set -e

# ensure Django knows the settings module
export DJANGO_SETTINGS_MODULE=${DJANGO_SETTINGS_MODULE:-conduit.settings}

python manage.py migrate --noinput
python manage.py collectstatic --noinput || true
python - <<'PY'
import os, django
django.setup()
from django.contrib.auth import get_user_model
User = get_user_model()

email = os.environ.get('DJANGO_ADMIN_EMAIL')
username = os.environ.get('DJANGO_ADMIN_USERNAME')
password = os.environ.get('DJANGO_ADMIN_PASSWORD')

u, created = User.objects.get_or_create(
    email=email,
    defaults={'username': username}
)
u.is_staff = True
u.is_superuser = True
if username:
    try:
        setattr(u, 'username', username)
    except Exception:
        pass
if password:
    u.set_password(password)
u.save()
print("admin user:", email, "|", "created" if created else "updated")
PY

exec "$@"

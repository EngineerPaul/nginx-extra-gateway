# CI/CD (GitHub Actions)

Непрерывная интеграция и деплой для **nginx-extra-gateway**.

Репозиторий: `https://github.com/EngineerPaul/nginx-extra-gateway.git`  
Прод-путь на сервере: `/var/www/Diary-project/nginx-extra-gateway`  
Ветка деплоя: `master`

Схема:

```text
push в master
  → GitHub Actions: CI (compose config, build, smoke /extra/blank)
  → если CI ок: SSH на сервер
  → git reset --hard origin/master
  → docker compose up --build -d
```

---

## 0. Что должно быть до CI

На сервере уже:

1. Склонирован репозиторий в `/var/www/Diary-project/nginx-extra-gateway`
2. Сеть Diary существует (`diary20_default` — поднимается вместе с Diary)
3. Сеть `docker network create extra_services` (если ещё нет)
4. Шлюз хотя бы раз успешно поднимался вручную
5. В Diary nginx настроен `proxy_pass` на `http://extra_nginx` для `/extra/`
6. У пользователя SSH есть права на `git` и `docker compose` в каталоге проекта

Проверка вручную:

```bash
cd /var/www/Diary-project/nginx-extra-gateway
git status
docker compose ps
curl -sS http://localhost/extra/blank
```

`.env` этому проекту **не** нужен.

---

## 1. SSH-ключ для GitHub Actions

Отдельный ключ только для CI (не личный `id_rsa`).

**На своём компьютере:**

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ./github_actions_ed25519 -N ""
```

| Файл | Куда |
|------|------|
| `github_actions_ed25519` | GitHub Secret `SSH_PRIVATE_KEY` |
| `github_actions_ed25519.pub` | на сервер в `~/.ssh/authorized_keys` |

Файлы ключей в `.gitignore`.

**На сервере** (пользователь из `SSH_USER`):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# вставить строку из github_actions_ed25519.pub в authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**Проверка с ПК:**

```bash
ssh -i ./github_actions_ed25519 -p 22 USER@HOST
```

---

## 2. Секреты в GitHub

Settings → Secrets and variables → Actions.

| Secret | Пример / смысл |
|--------|----------------|
| `SSH_HOST` | хост сервера (выданный сервером IP) |
| `SSH_USER` | пользователь SSH |
| `SSH_PORT` | обычно `22` |
| `SSH_PRIVATE_KEY` | весь приватный ключ, включая `BEGIN`/`END` |
| `DEPLOY_PATH` | `/var/www/Diary-project/nginx-extra-gateway` |

Опционально:

| Secret | По умолчанию |
|--------|----------------|
| `DEPLOY_BRANCH` | `master` |

---

## 3. Файлы в репозитории

```text
.github/workflows/ci-cd.yml        # pipeline: CI + deploy
.github/deploy_ssh.sh              # команды на сервере после git reset
.github/docker-compose.ci.yaml     # override для smoke-test (без analyses)
.github/default.ci.conf            # nginx-конфиг для CI smoke-test
```

### Job `ci`

На `ubuntu-latest` при push/PR в `master`:

1. Checkout
2. `docker compose config` (+ CI override)
3. Создание внешних сетей (только для smoke-test в CI)
4. `docker compose build`
5. `docker compose -f … -f .github/docker-compose.ci.yaml up` + проверка `/extra/blank`
   (в CI analyses отключён — подменяется `default.ci.conf`)

Deploy **не** запускается на pull_request.

### Job `deploy`

Только при **push** в `master` (или `workflow_dispatch`) после успешного CI:

1. SSH (`appleboy/ssh-action`)
2. `cd $DEPLOY_PATH`
3. `git fetch` + `git reset --hard origin/master`
4. `.github/deploy_ssh.sh`:
   - проверка сетей `diary20_default` и `extra_services`
   - `docker compose up --build -d`
   - `docker compose ps`

---

## 4. Права Git на сервере

CI делает `git fetch` / `reset --hard` от имени `SSH_USER`.

Предпочтительно: Deploy key (read-only) на репозиторий + remote по SSH.

```bash
cd /var/www/Diary-project/nginx-extra-gateway
git remote -v
# origin должен тянуться без пароля
```

---

## 5. Первый запуск

1. Закоммитить и запушить workflow в `master`
2. GitHub → **Actions** — дождаться зелёного CI и Deploy
3. Проверить: `curl http://localhost/extra/blank` (или через Diary)

Ручной запуск: Actions → workflow → **Run workflow**.

---

## 6. Типовые ошибки

| Симптом | Что проверить |
|---------|----------------|
| `Permission denied (publickey)` | `SSH_PRIVATE_KEY`, `authorized_keys`, `SSH_USER` |
| `Connection refused` | `SSH_HOST`, `SSH_PORT`, firewall |
| `DEPLOY_PATH` not found | секрет = реальный каталог |
| `git` authentication failed | deploy key / remote URL |
| `network diary20_default not found` | Diary поднят |
| `network extra_services not found` | `docker network create extra_services` |
| CI зелёный, сайт старый | логи Deploy; `docker compose ps` |

---

## 7. Чеклист

- [ ] Проект на сервере в `/var/www/Diary-project/nginx-extra-gateway` работает вручную
- [ ] Сети `diary20_default` и `extra_services` есть
- [ ] Pub-ключ CI в `authorized_keys`
- [ ] Секреты: `SSH_HOST`, `SSH_USER`, `SSH_PORT`, `SSH_PRIVATE_KEY`, `DEPLOY_PATH`
- [ ] Git на сервере тянет `origin/master` без интерактива
- [ ] В репозитории есть `.github/workflows/ci-cd.yml` и `.github/deploy_ssh.sh`
- [ ] Push в `master` → Actions зелёные → контейнер обновился

---

## 8. Безопасность

- Не коммитить приватные ключи (`github_actions_ed25519` в `.gitignore`)
- `git reset --hard` на проде затирает локальные правки в каталоге деплоя
- Секреты GitHub видны только админам репозитория

---

## Связанные документы

- `README.md` — как устроен шлюз и сети

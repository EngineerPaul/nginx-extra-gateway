# nginx-extra-gateway

Отдельный nginx-шлюз для сервисов под префиксом `/extra`.  
Не часть Diary — отдельный репозиторий; Diary nginx только проксирует сюда запросы с путём `/extra/...`.

## Как это работает

```
Браузер
   │
   ▼
diary nginx  (:80 / :443)
   │  proxy_pass http://extra_nginx;
   │  сеть diary20_default
   ▼
extra_nginx  (этот проект)
   │
   ├─ /extra/           → extra.html (каталог сервисов)
   ├─ /extra/blank      → статическая заглушка (проверка цепочки)
   ├─ /extra/analyses/  → analyses_frontend:80  (сеть extra_services)
   ├─ /extra/analyses/api/ → analyses_backend:8000
   ├─ /extra/summary/   → summary:8000
   ├─ /extra/marketing/ → marketing:8000
   └─ /extra/calendar/  → calendar:8000
```

`extra_nginx` сидит в **двух** Docker-сетях:

| Сеть | Зачем |
|------|--------|
| `diary20_default` | Diary видит контейнер по имени `extra_nginx` |
| `extra_services` | Шлюз видит независимые сервисы (`analyses_*` и др.) по `container_name` |

Маршруты `/extra/<сервис>/...` задаются файлами в `nginx/conf.d/` (например `analyses.conf`), которые подключаются из одного `server` в `default.conf`.

## Подготовка на сервере

Один раз создать общую сеть для /extra-сервисов:

```bash
docker network create extra_services
```

Имя сети Diary обычно `{имя_проекта_compose}_default`. Проверить:

```bash
docker network ls | grep default
```

Если у вас не `diary20_default`, поправьте `networks.diary_net.name` в `docker-compose.yaml`.

## Запуск

Diary должен быть уже поднят (сеть `diary20_default` существует).

```bash
cd /path/to/nginx-extra-gateway
docker compose up -d --build
```

Проверка:

```bash
curl http://localhost/extra/blank
```

Для прямой отладки без Diary раскомментируйте `ports: ["8088:80"]` в compose и:

```bash
curl http://localhost:8088/extra/blank
```

## Подключение сервиса (на примере analyses)

Сервис — отдельный compose-проект. Он поднимается в своей сети и **дополнительно** подключается к `extra_services`.

1. Задать стабильные `container_name` (`analyses_frontend`, `analyses_backend`).
2. Добавить сеть:

```yaml
services:
  frontend:
    container_name: analyses_frontend
    networks: [default, extra_net]
  backend:
    container_name: analyses_backend
    networks: [default, extra_net]

networks:
  extra_net:
    external: true
    name: extra_services
```

3. В шлюзе описать location в `nginx/conf.d/<сервис>.conf` и `include` в `default.conf` (для analyses уже сделано).
4. Порты наружу для работы через Diary не обязательны — трафик идёт по Docker DNS.

Порядок: сначала сервис (analyses), потом `docker compose up -d --build` шлюза (или перезагрузка nginx после появления контейнеров).

## Структура

```
docker-compose.yaml
nginx/
  dockerfile
  nginx.conf
  conf.d/
    default.conf    # server + blank + include маршрутов
    extra.conf      # /extra/ → extra.html
    analyses.conf   # /extra/analyses → frontend/backend
    summary.conf    # /extra/summary → summary
    marketing.conf  # /extra/marketing → marketing (sda-marketing)
    calendar.conf   # /extra/calendar → calendar
  html/
    blank.html
    extra.html
```

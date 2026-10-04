# Log aggregation

All container logs can be collected into [Loki](https://grafana.com/oss/loki/) and browsed in
[Grafana](https://grafana.com/oss/grafana/), which is a lot more comfortable than `docker compose logs`
when several containers are involved or when you want to look at a request that happened an hour ago.

```bash
docker compose up -d grafana
```

This starts three containers:

| Container | Purpose |
| --------- | ------- |
| `alloy`   | [Grafana Alloy](https://grafana.com/docs/alloy/latest/) collects the logs of all containers of this compose project through the docker socket and pushes them to Loki. It replaces Promtail, which reached end of life in March 2026. |
| `loki`    | Stores the logs on a local volume |
| `grafana` | Web interface to search and visualize them |

Afterwards open [http://grafana.local](http://grafana.local) and log in with `admin` / `admin`,
which can be changed with `GRAFANA_USER` and `GRAFANA_PASSWORD` in your `.env` file.

## What is collected

Alloy reads the docker logs of every container of this compose project, so nothing has to be
mounted or configured per service. Containers of other projects running on the same docker host are
not touched, the scoping is done with the `com.docker.compose.project` label and therefore relies on
`COMPOSE_PROJECT_NAME` being set in your `.env` file, which `bootstrap.sh` does for you.

The Nextcloud containers already write `data/nextcloud.log`, the cron log and the xdebug log to
their stdout and Apache logs there as well, which means the full Nextcloud log ends up in Loki
without any further setup. One container log therefore mixes several formats, the `log_type`
label separates them again:

| `log_type` | Content |
| ---------- | ------- |
| `nextcloud` | `nextcloud.log`, parsed as JSON |
| `access` | The access log of the nginx proxy, which sees every request of the whole setup |
| `apache_access` | The access log of Apache itself, which also covers internal requests that never pass the proxy |
| `apache_error` | Apache error log, this is where PHP fatals and warnings show up that never reach `nextcloud.log` |
| `xdebug` | Xdebug output |

Everything without one of those formats, for example the databases, the signaling server or the
cron output, has no `log_type` and is stored as it is.

## Labels

Every log entry carries `container`, `service` and `job="docker"`. Loki queries start with a
stream selector, so only fields with few, known values are labels, everything with many possible
values is [structured metadata](https://grafana.com/docs/loki/latest/get-started/labels/structured-metadata/)
instead, which is filtered after a `|` and does not create a stream per value.

Lines from `nextcloud.log` are parsed as JSON and get:

- Labels: `level`, `app`
- Structured metadata: `reqId`, `user`, `method`, `url`, `scriptName`, `remoteAddr`,
  `userAgent`, `version` and `exception`, the class name of a logged exception

The proxy is configured with a `LOG_FORMAT` that writes logfmt instead of the combined format, so
its access lines carry `vhost` as a label and `method`, `path`, `query`, `route`, `status`,
`bytes`, `duration`, `upstream_time`, `remote_addr`, `user_agent` and `reqId` as structured
metadata. Status codes are deliberately not labels, a label per status code would multiply the
streams of every container.

Grouping by `path` is pointless in Nextcloud because it contains conversation tokens, user names,
file paths and ids, so almost every request has its own. `route` is the same path with those parts
replaced, which is what the dashboard groups by:

| Path | Route |
| ---- | ----- |
| `/ocs/v2.php/apps/spreed/api/v1/chat/jetukpyo` | `/ocs/v2.php/apps/spreed/api/v1/chat/{token}` |
| `/remote.php/dav/files/admin/Photos/image.jpg` | `/remote.php/dav/files/{path}` |
| `/index.php/avatar/alice/64` | `/index.php/avatar/{user}/{id}` |
| `/apps/files/js/merged-index.js` | `{static}.js` |

The rules live at the end of the proxy block in `config.alloy` and are easy to extend, each one
replaces only its capture group and keeps the rest of the path.

`duration` is the request time in seconds, which is what the response time panels are built on,
and `reqId` is the request id Nextcloud returns in its `X-Request-Id` response header. It ties an
access line to the `nextcloud.log` entries of the same request, so a slow or failing request can
be opened in the application log with one click. Responses that Nextcloud does not render through
its app framework, for example WebDAV through `remote.php` or static files, have no such header
and therefore no `reqId`.

The `level` label uses the same five values everywhere, `debug`, `info`, `warn`, `error` and
`fatal`, so a single query covers the whole setup. Besides Nextcloud it is set for:

- `talk-janus`, which prefixes everything but info with `[FATAL]`, `[ERR]` or `[WARN]`
- `talk-recording`, which logs in Pythons default `LEVEL:logger:message` format
- the Apache error log, whose `[php:error]` style tags are mapped to the same names

The signaling server writes plain Go log lines without a level and there is nothing else worth
labelling in them, the same is true for the cron output and the databases. For those Loki still
adds its own guess as the `detected_level` structured metadata field.

## Dashboards

Three dashboards are provisioned, the dropdown in the top left switches between them and keeps
the selected time range:

| Dashboard | Use it for |
| --------- | ---------- |
| **Nextcloud logs** | The application log. Errors and exceptions at the top, volume by level, every exception class over time so that a new one stands out, the most frequent exceptions, where errors come from and the log itself. Clicking an exception or app in a table filters the log to it. |
| **Access log** | HTTP traffic as seen by the proxy. Share of 5xx and 4xx responses and the p95 response time at the top, requests by status class over time, p50/p95/p99 response time, sortable tables of the failing, slowest and busiest routes, and every single request slower than a configurable threshold, whose request id opens the matching Nextcloud log entries. |
| **Container logs** | Everything else, the databases, Redis, the Talk backends, the Apache error log and the tooling containers, by service and level. |

The tiles at the top only turn amber or red when something needs a look. Filters named `Log: …` only
apply to the log list at the bottom, so the overview above never changes unnoticed, while the instance
or host filter and `Search` apply to every panel.

Response times leave out the requests Talk keeps open on purpose, long polling of the chat and the
internal signaling as well as websockets, otherwise they would dominate every latency panel. For the
same reason the 4xx share ignores `499`, which nginx logs when a client closes such a request.

## Useful queries

Errors anywhere in the setup, Nextcloud instances and Talk backends alike:

```logql
{level=~"error|fatal"}
```

Only the application log of the Nextcloud instances, without access lines and cron output:

```logql
{log_type="nextcloud"}
```

Requests that failed with a server error:

```logql
{log_type="access"} | status=~"5.."
```

Requests that took longer than two seconds:

```logql
{log_type="access"} | duration > 2
```

The 95th percentile of the response time per host:

```logql
quantile_over_time(0.95, {log_type="access"} | unwrap duration [5m]) by (vhost)
```

The busiest routes of the last hour:

```logql
topk(10, sum by (route) (count_over_time({log_type="access"}[1h])))
```

The most frequent exceptions of the last hour:

```logql
topk(10, sum by (exception) (count_over_time({log_type="nextcloud"} | exception != "" [1h])))
```

Everything a single container logged:

```logql
{container="master-nextcloud-1"}
```

All log entries belonging to one request, the request id can also be copied from the
`X-Request-Id` response header:

```logql
{service=~".+"} | reqId = `bJSJXYCTU0gBjVZq5Vtm`
```

Log entries of one Nextcloud app only:

```logql
{app="spreed"}
```

Everything the Talk backends logged:

```logql
{service=~"talk-.+"}
```

Number of errors per app over the last hour:

```logql
sum by (app) (count_over_time({level=~"error|fatal"}[1h]))
```

In the log view of Grafana every entry has a `reqId` field. Clicking it opens all log entries of
that request, which is the fastest way to find out what else happened while a request failed.

## Configuration

- Collection pipeline: `docker/configs/alloy/config.alloy`
- Loki: `docker/configs/loki/config.yml`
- Grafana datasource and dashboards: `docker/configs/grafana/`

Logs are kept for 7 days, this can be changed with `LOKI_RETENTION_PERIOD` in your `.env` file.

Grafana asks for a login instead of allowing anonymous access, because an anonymous session cannot
save dashboard changes and makes Grafana show `Unauthorized` banners for the user specific parts
of its own API. Adding `GF_AUTH_ANONYMOUS_ENABLED: "true"` to the environment of the `grafana`
service in `docker-compose.yml` enables the login free variant with those limitations.

To see which containers Alloy discovered and what the pipeline does to a log line, open the Alloy
interface at [http://alloy.local](http://alloy.local).

After changing `config.alloy`, recreate the container instead of restarting it:

```bash
docker compose up -d --force-recreate alloy
```

The file is bind mounted as a single file, so an editor that writes a new file instead of changing
the existing one leaves the running container with the old content. Alloy also remembers how far it
has read, which means only log lines written after the recreate carry new labels.

!!! note

    Since all containers of the project are collected, `loki`, `alloy` and `grafana` log their own
    output into Loki as well. If Loki is unreachable, Alloy keeps logging that error and picks it up again on the next
    run, so it is normal to see a burst of Alloy errors after Loki was restarted.

## Global scale

```
docker compose up -d proxy portal gs1 gs2 lookup database-mysql
```

Users are named the same as the instance name, e.g. `gs1`, `gs2`

## [Fulltextsearch](https://github.com/nextcloud/fulltextsearch)

```
docker compose up -d elasticsearch elasticsearch-ui
```

- Address for configuring in Nextcloud: `http://elastic:elastic@elasticsearch:9200`
- Address to access Elasticsearch from outside: `http://elastic:elastic@elasticsearch.local`
- Address for accessing the UI: <http://elasticsearch-ui.local/>

`sudo sysctl -w vm.max_map_count=262144`

## Log aggregation

```
docker compose up -d grafana
```

Collects the logs of all containers of the setup into Loki and makes them searchable in Grafana at
<http://grafana.local/>. See [log aggregation](../tools/logs.md) for details.

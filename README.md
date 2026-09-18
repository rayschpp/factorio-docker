# Factorio Docker

Factorio server on scratch docker server.

## Compose example

```yaml
service:
  factorio:
    build:
      context: .
      args:
        FACTORIO_VERSION: "2.1.19"
    volumes:
      - savegames:/<todo>
      - mods: /<todo>
    ports:
      - "34197:34197/udp"
```


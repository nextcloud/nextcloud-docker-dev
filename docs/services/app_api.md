# AppAPI

For [AppAPI](https://github.com/nextcloud/app_api) the [Docker Socket Proxy](https://github.com/nextcloud/docker-socket-proxy) (DSP) is required to work.

## HTTP AppAPI DSP

### 1. Start the HTTP DSP container

```bash
docker compose up -d appapi-dsp
```

### 2. Configure Deploy daemon

After the DSP container is running, configure the Deploy daemon in AppAPI admin settings with the following parameters:

- **Host**: `nextcloud-appapi-dsp-http:2375`
- **Nextcloud URL**: `http://nextcloud.local` (locally always use http)
- **Enable https**: `false`
- **Network**: `master_default` (the network of nextcloud-docker-dev docker-compose, by default it is `master_default`)
- **HaProxy password**: `some_secure_password`

or via OCC CLI:

```bash
./scripts/occ.sh nextcloud -- app_api:daemon:register dsp_http "DSP HTTP" docker-install http "nextcloud-appapi-dsp-http" "http://nextcloud.local" --net=master_default --set-default
```

## HTTPS AppAPI DSP

For HTTPS DSP setup, please refer to the [HTTPS (remote)](https://github.com/nextcloud/docker-socket-proxy?tab=readme-ov-file#httpsremote) section.

### 1. Generate self-signed certificates

Following the instruction from the DSP repository, generate and place the self-signed certificate in the `nextcloud-docker-dev/data/ssl/app_api/app_api.pem` directory.

> **Note**: Additionally, you can copy the `app_api.pem` file to the `nextcloud-docker-dev/data/shared` directory 
> to be able to access it for import in each nextcloud dev container (e.g. `occ security:certificates:import /shared/app_api.pem`).

### 2. Start the HTTPS DSP container

```bash
docker compose up -d appapi-dsp-https
```

### 3. Configure Deploy daemon

After the DSP container is running and the certificate is imported in Nextcloud, configure the Deploy daemon in AppAPI admin settings with the following parameters:

- **Host**: `<nextcloud-appapi-dsp-https or BIND_ADDRESS IP>:2375` (use host depending on your setup)
- **Nextcloud URL**: `http://nextcloud.local` (locally always use http)
- **Enable https**: `true`
- **Network**: `host` (with https enabled, the network is forced to `host`)
- **HaProxy password**: `some_secure_password`

or via OCC CLI:

```bash
./scripts/occ.sh nextcloud -- app_api:daemon:register dsp_https "DSP HTTPS" docker-install https "nextcloud-appapi-dsp-https" "http://nextcloud.local" --net=host --set-default
```


## Environment variables

The list of available environment variables for the AppAPI DSP is listed in its repository,
and in the `example.env` file.

## Troubleshooting

### Image of AppAPI DSP is not accessible

In case the AppAPI DSP image is not accessible, you can build it locally by cloning the [Docker Socket Proxy](https://github.com/nextcloud/docker-socket-proxy) repository and running the following commands:

```bash
git clone https://github.com/nextcloud/docker-socket-proxy.git
```

```bash
cd docker-socket-proxy 
```

```bash
 docker build -f ./Dockerfile -t nextcloud-appapi-dsp:latest ./
```

After that change the image name in the `docker-compose.yml` file
for `appapi-dsp` or `appapi-dsp-https` service to `nextcloud-appapi-dsp:latest` and try again.

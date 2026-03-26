# Hive 3 + Impala Dual-Mode (Kerberos + Open)

Languages:
- [Portuguese](README.md)
- English (this file)
- [Spanish (Mexico)](README.es-MX.md)

Complete local environment for Talend and JDBC tests, with both modes active at the same time:

- Hive 3.1.3 with Kerberos endpoint and LDAP username/password endpoint
- Impala 4.5.0 with Kerberos endpoint and LDAP username/password endpoint
- Local MIT Kerberos KDC (`EXAMPLE.COM`)
- Local OpenLDAP for simple lab authentication
- HDFS + YARN
- PostgreSQL for Hive Metastore

## 1) Prerequisites

- Docker + Docker Compose
- For Kerberos tests on Windows:
  - MIT Kerberos for Windows, with `kinit`/`klist`
  - `krb5.ini` file
  - installation tutorial: [docs/windows/mit-kerberos-client.en.md](./docs/windows/mit-kerberos-client.en.md)
  - test user keytab (`talend.user.keytab`)

## 2) Start environment from scratch

Convenience scripts at repo root:

```bash
./up.sh
./recreate.sh
./sync-keytab.sh
./down.sh
./ps.sh
./logs.sh
./logs.sh hive-server2
./test.sh
```

Notes:

- `./up.sh` and `./recreate.sh` automatically synchronize `./talend.user.keytab` into the repo root
- `./up.sh` and `./recreate.sh` also wait until demo data bootstrap finishes successfully
- `./sync-keytab.sh` only refreshes that file, without recreating services
- `./talend.user.keytab` is ignored by Git and should not be committed

Direct equivalents:

```bash
cd /opt/cloudera-kerberos
docker compose down -v --remove-orphans
docker compose up -d --build
docker compose ps -a
```

If you only want to restart without deleting data:

```bash
docker compose up -d
docker compose ps
```

## 3) Locally generated files

- `./talend.user.keytab`: local copy of the keytab exported by the KDC for client tools such as DBeaver and Talend

## 4) Ports and endpoints

Infra:

- `88/tcp` + `88/udp`: KDC
- `749/tcp`: kadmin
- `9870`: NameNode UI
- `8020`: HDFS RPC
- `8088`: YARN UI
- `19888`: JobHistory UI
- `9083`: Hive Metastore
- `5433`: PostgreSQL metastore

HiveServer2:

- `10000`: Hive with Kerberos
- `10001`: Hive with LDAP username/password

Impala:

- `21050`: Impala with Kerberos (HS2)
- `21051`: Impala with LDAP username/password (HS2)
- `25000`: Kerberos UI
- `25001`: LDAP UI

## 5) Lab principals and credentials

Realm: `EXAMPLE.COM`

- admin: `admin/admin@EXAMPLE.COM` password `admin123`
- Talend user: `talend@EXAMPLE.COM` password `talend123`
- LDAP user: `admin` password `Admin123$`
- Hive service: `hive/localhost@EXAMPLE.COM`
- Impala service (client): `impala/impala.hadoop.local@EXAMPLE.COM`
- Impala service (internal): `impala/impala-statestored@EXAMPLE.COM`, `impala/impala-catalogd@EXAMPLE.COM`

## Demo datasets

The environment starts with three populated sample databases that are equivalent to each other:

- `demo_sales_en`: canonical model in English
- `demo_vendas_ptbr`: translated model in Brazilian Portuguese
- `demo_ventas_esmx`: translated model in Mexican Spanish

Each database contains five related tables:

- EN: `customers`, `categories`, `products`, `orders`, `order_items`
- PT-BR: `clientes`, `categorias`, `produtos`, `pedidos`, `itens_pedido`
- ES-MX: `clientes`, `categorias`, `productos`, `pedidos`, `partidas_pedido`

The three demo databases are bootstrapped automatically in Hive:

- Hive LDAP (`10001`): full read/exploration flow
- Hive Kerberos (`10000`): metadata and simple reads such as `show tables` and `select ... limit`

On Impala endpoints, authentication and connectivity are working, but the demo schemas are not surfaced reliably yet because of a compatibility issue between Impala 4.5.0 catalog and Hive Metastore 3.1.3 (`get_dataconnectors`).

Portable Hive quick queries:

```sql
show tables in demo_sales_en;
select * from demo_vendas_ptbr.pedidos limit 5;
select * from demo_ventas_esmx.partidas_pedido limit 5;
```

## 6) Quick health check

```bash
./ps.sh
```

Automated smoke test:

```bash
./test.sh
```

Expected:

- `hb-kdc`: `healthy`
- `hb-openldap`: `healthy`
- `hb-postgres`: `healthy`
- `hb-hdfs-init`: `Exited (0)`
- `hb-dataset-seed`: `Exited (0)`
- `hb-hive-metastore`: `healthy`
- `hb-hive-server2`: `Up`
- `hb-hive-server2-open`: `Up`
- `hb-impala-daemon`: `Up`
- `hb-impala-daemon-open`: `Up`

Port checks:

```bash
nc -zv localhost 10000
nc -zv localhost 10001
nc -zv localhost 21050
nc -zv localhost 21051
```

## 7) Talend - username/password connection (first test)

In Hive connection wizard (Repository):

- `Connection Mode`: `Standalone`
- `Hive Version`: `Hive 2`
- `Hadoop Version`: `Hadoop 3`
- `Server`: `localhost`
- `Port`: `10001`
- `DataBase`: `default`
- `Login`: `admin`
- `Password`: `Admin123$`
- `Additional JDBC Settings`: `auth=LDAP`

Note: in some Talend versions, `String of Connection` is read-only. In that case, always use `Additional JDBC Settings` to inject JDBC parameters.

## 8) Talend - Kerberos connection (Hive)

### 7.1 Prepare `krb5.ini` on Windows

Example file:

- [examples/windows/krb5.ini](./examples/windows/krb5.ini)

Use one option:

- copy to `C:\Windows\krb5.ini` (default), or
- set `KRB5_CONFIG` variable pointing to another path.

### 7.2 Ensure keytab on Windows

Copy keytab generated in KDC container:

```bash
cd /opt/cloudera-kerberos
docker cp hb-kdc:/keytabs/talend.user.keytab /tmp/talend.user.keytab
```

Then copy `/tmp/talend.user.keytab` to Windows, for example:

- `C:\Users\<YOUR_USER>\talend.user.keytab`

### 7.3 Generate Kerberos ticket on Windows

In `cmd.exe`:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<YOUR_USER>\talend.user.keytab talend@EXAMPLE.COM
klist
```

Expected in `klist`: default principal `talend@EXAMPLE.COM`.

### 7.4 Configure in Talend (without “Use Kerberos authentication” checkbox)

If the screen does not show Kerberos checkbox and URL is locked, use:

- `Server`: `localhost`
- `Port`: `10000`
- `DataBase`: `default`
- `Login`: empty
- `Password`: empty
- `Additional JDBC Settings`: `auth=kerberos;principal=hive/localhost@EXAMPLE.COM`

Equivalent to:

```text
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/localhost@EXAMPLE.COM
```

## 9) DBeaver

### 9.1 Hive with username/password

In DBeaver:

- `Driver`: `Apache Hive`
- `Host`: `localhost`
- `Port`: `10001`
- `Database`: `default`
- `User name`: `admin`
- `Password`: `Admin123$`

Reference JDBC URL:

```text
jdbc:hive2://localhost:10001/default;auth=LDAP
```

### 9.2 Hive with Kerberos

Before connecting on Windows:

1. copy `./talend.user.keytab` to the Windows machine, for example `C:\Users\<YOUR_USER>\talend.user.keytab`
2. copy [examples/windows/krb5.ini](./examples/windows/krb5.ini) to `C:\Windows\krb5.ini`, or point `KRB5_CONFIG` to another path
3. install MIT Kerberos for Windows and confirm that `kinit` and `klist` are available:

Detailed installation tutorial:

- [docs/windows/mit-kerberos-client.en.md](./docs/windows/mit-kerberos-client.en.md)

```bat
where kinit
where klist
```

4. generate the Kerberos ticket:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<YOUR_USER>\talend.user.keytab talend@EXAMPLE.COM
klist
```

In DBeaver:

- `Driver`: `Apache Hive`
- `Host`: `localhost`
- `Port`: `10000`
- `Database`: `default`
- `User name`: empty
- `Password`: empty

Reference JDBC URL:

```text
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/localhost@EXAMPLE.COM
```

### 9.3 Impala with username/password

In DBeaver:

- `Driver`: `Apache Impala`
- `Host`: `localhost`
- `Port`: `21051`
- `Database`: `default`
- `User name`: `admin`
- `Password`: `Admin123$`

Reference JDBC URL:

```text
jdbc:impala://localhost:21051/default;AuthMech=3;UID=admin;PWD=Admin123$
```

### 9.4 Impala with Kerberos

Before connecting on Windows:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<YOUR_USER>\talend.user.keytab talend@EXAMPLE.COM
klist
```

In DBeaver:

- `Driver`: `Apache Impala`
- `Host`: `localhost`
- `Port`: `21050`
- `Database`: `default`
- `User name`: empty
- `Password`: empty

Reference JDBC URL:

```text
jdbc:impala://localhost:21050/default;AuthMech=1;KrbRealm=EXAMPLE.COM;KrbHostFQDN=impala.hadoop.local;KrbServiceName=impala
```

## 10) Reference JDBC

Hive with username/password:

```text
jdbc:hive2://localhost:10001/default;auth=LDAP
```

Hive with Kerberos:

```text
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/localhost@EXAMPLE.COM
```

Impala with username/password:

```text
jdbc:impala://localhost:21051/default;AuthMech=3;UID=admin;PWD=Admin123$
```

Impala with Kerberos:

```text
jdbc:impala://localhost:21050/default;AuthMech=1;KrbRealm=EXAMPLE.COM;KrbHostFQDN=impala.hadoop.local;KrbServiceName=impala
```

Sample queries for Hive:

```sql
show tables in demo_sales_en;

select * from demo_sales_en.orders limit 5;

select * from demo_vendas_ptbr.pedidos limit 5;

select * from demo_ventas_esmx.partidas_pedido limit 5;
```

## 11) Quick troubleshooting

Handshake/transport error in Talend:

- confirm correct port (`10001` non-Kerberos, `10000` Kerberos)
- confirm `Additional JDBC Settings`
- check whether Hive/Impala JDBC driver is installed in Talend

`kinit` authenticating against corporate AD instead of `EXAMPLE.COM`:

- confirm that the MIT Kerberos for Windows `kinit`/`klist` is being used
- validate with `where kinit` and `where klist`

`PortUnreachableException` in `kinit`:

- Docker/KDC is not reachable from Windows machine
- confirm `docker compose ps` and `88/udp` and `88/tcp` ports published

Environment unstable after many tests:

```bash
cd /opt/cloudera-kerberos
docker compose down -v --remove-orphans
docker compose up -d --build
docker compose ps -a
```

If you want to validate everything automatically after changes:

```bash
./scripts/smoke-test.sh
```

## 12) Useful logs

```bash
docker logs -f hb-kdc
docker logs -f hb-hive-metastore
docker logs -f hb-hive-server2
docker logs -f hb-hive-server2-open
docker logs -f hb-impala-daemon
docker logs -f hb-impala-daemon-open
```

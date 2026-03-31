# Hive 3 + Impala Modo Dual (Kerberos + Open)

Idiomas:
- [Português](README.md)
- [English](README.en.md)
- Español (México) (este archivo)

Entorno local completo para pruebas con Talend y JDBC, con ambos modos activos al mismo tiempo:

- Hive 3.1.3 con endpoint Kerberos y endpoint LDAP con usuario/contraseña
- Impala 4.5.0 con endpoint Kerberos y endpoint LDAP con usuario/contraseña
- KDC MIT Kerberos local (`EXAMPLE.COM`)
- OpenLDAP local para autenticación simple del laboratorio
- HDFS + YARN
- PostgreSQL para Hive Metastore

## 1) Prerrequisitos

- Docker + Docker Compose
- Para pruebas Kerberos en Windows:
  - MIT Kerberos for Windows, con `kinit`/`klist`
  - archivo `krb5.ini`
  - tutorial de instalación: [docs/windows/mit-kerberos-client.es-MX.md](./docs/windows/mit-kerberos-client.es-MX.md)
  - keytab del usuario de prueba (`talend.user.keytab`)

## 2) Levantar entorno desde cero

Scripts de conveniencia en la raíz:

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

Notas:

- `./up.sh` y `./recreate.sh` sincronizan automáticamente `./talend.user.keytab` en la raíz del repositorio
- `./up.sh` y `./recreate.sh` también exportan automáticamente los XMLs de los stacks `kerberos` y `open` a `./exported-configs`
- `./up.sh` y `./recreate.sh` también esperan a que termine correctamente el bootstrap de datos de ejemplo
- `./sync-keytab.sh` solo actualiza ese archivo, sin recrear servicios
- `./talend.user.keytab` queda ignorado por Git y no debe ser commitado

Equivalentes directos:

```bash
cd /opt/cloudera-kerberos
docker compose down -v --remove-orphans
docker compose up -d --build
docker compose ps -a
```

Si solo quieres reiniciar sin borrar datos:

```bash
docker compose up -d
docker compose ps
```

## 3) Archivos generados localmente

- `./talend.user.keytab`: copia local de la keytab exportada por el KDC para herramientas cliente como DBeaver y Talend

## 4) Puertos y endpoints

Infra:

- `88/tcp` + `88/udp`: KDC
- `749/tcp`: kadmin
- `9870`: HTTP seguro de NameNode (`WebHDFS` con Kerberos)
- `9871`: HTTP open de NameNode (`WebHDFS` sin Kerberos)
- `8020`: HDFS RPC seguro
- `8021`: HDFS RPC open
- `14000`: `HttpFS` con Kerberos
- `14001`: `HttpFS` sin Kerberos
- `8088`: UI de YARN
- `19888`: UI de JobHistory
- `9083`: Hive Metastore
- `5433`: metastore PostgreSQL

HiveServer2:

- `10000`: Hive con Kerberos
- `10001`: Hive con usuario/contraseña vía LDAP

Impala:

- `21050`: Impala con Kerberos (HS2)
- `21051`: Impala con usuario/contraseña vía LDAP (HS2)
- `25000`: UI Kerberos
- `25001`: UI LDAP

### Acceso HTTP a HDFS desde el host

Usa `localhost` para pruebas rápidas desde el host local:

- `WebHDFS` con Kerberos: `http://localhost:9870/webhdfs/v1/?op=LISTSTATUS`
- `WebHDFS` sin Kerberos: `http://localhost:9871/webhdfs/v1/?op=LISTSTATUS&user.name=root`
- `HttpFS` con Kerberos: `http://localhost:14000/webhdfs/v1/?op=LISTSTATUS`
- `HttpFS` sin Kerberos: `http://localhost:14001/webhdfs/v1/?op=LISTSTATUS&user.name=root`

Ejemplos con `curl`:

```bash
curl --negotiate -u : -sS "http://localhost:9870/webhdfs/v1/?op=LISTSTATUS"
curl -sS "http://localhost:9871/webhdfs/v1/?op=LISTSTATUS&user.name=root"
curl --negotiate -u : -sS "http://localhost:14000/webhdfs/v1/?op=LISTSTATUS"
curl -sS "http://localhost:14001/webhdfs/v1/?op=LISTSTATUS&user.name=root"
```

Para `WebHDFS`, las operaciones de lectura y escritura hacen redirect hacia el DataNode. En el host local, mantén estas puertas accesibles también:

- `9864`: DataNode HTTP del cluster Kerberos
- `9865`: DataNode HTTP del cluster open

Ejemplo de escritura y lectura vía `WebHDFS` open desde el host:

```bash
printf 'hello-webhdfs-open\n' >/tmp/webhdfs-open.txt

CREATE_URL="$(curl -sS -D - -o /dev/null -X PUT \
  "http://localhost:9871/webhdfs/v1/tmp/webhdfs-open.txt?op=CREATE&overwrite=true&user.name=root" \
  | awk '/^Location:/ {print $2}' | tr -d '\r')"
CREATE_URL="${CREATE_URL/datanode-open.hadoop.local:9865/127.0.0.1:9865}"

curl -sS -X PUT -H 'Content-Type: application/octet-stream' \
  --data-binary @/tmp/webhdfs-open.txt "${CREATE_URL}"

OPEN_URL="$(curl -sS -D - -o /dev/null \
  "http://localhost:9871/webhdfs/v1/tmp/webhdfs-open.txt?op=OPEN&user.name=root" \
  | awk '/^Location:/ {print $2}' | tr -d '\r')"
OPEN_URL="${OPEN_URL/datanode-open.hadoop.local:9865/127.0.0.1:9865}"

curl -sS "${OPEN_URL}"
curl -sS -X DELETE "http://localhost:9871/webhdfs/v1/tmp/webhdfs-open.txt?op=DELETE&user.name=root"
```

Ejemplo equivalente vía `HttpFS` open desde el host:

```bash
printf 'hello-httpfs-open\n' >/tmp/httpfs-open.txt

CREATE_URL="$(curl -sS -D - -o /dev/null -X PUT \
  "http://localhost:14001/webhdfs/v1/tmp/httpfs-open.txt?op=CREATE&overwrite=true&user.name=root" \
  | awk '/^Location:/ {print $2}' | tr -d '\r')"

curl -sS -X PUT -H 'Content-Type: application/octet-stream' \
  --data-binary @/tmp/httpfs-open.txt "${CREATE_URL}"

curl -sS "http://localhost:14001/webhdfs/v1/tmp/httpfs-open.txt?op=OPEN&user.name=root"
curl -sS -X DELETE "http://localhost:14001/webhdfs/v1/tmp/httpfs-open.txt?op=DELETE&user.name=root"
```

Si prefieres aliases en lugar de `localhost`, los hostnames internos son:

- `namenode.hadoop.local`: `WebHDFS` con Kerberos
- `namenode-open.hadoop.local`: `WebHDFS` sin Kerberos
- `httpfs.hadoop.local`: `HttpFS` con Kerberos
- `httpfs-open.hadoop.local`: `HttpFS` sin Kerberos

## 5) Principals y credenciales del laboratorio

Realm: `EXAMPLE.COM`

- admin: `admin/admin@EXAMPLE.COM` contraseña `admin123`
- usuario Talend: `talend@EXAMPLE.COM` contraseña `talend123`
- usuario LDAP: `admin` contraseña `Admin123$`
- servicio Hive: `hive/hiveserver2.hadoop.local@EXAMPLE.COM`
- servicio Impala (cliente): `impala/impala.hadoop.local@EXAMPLE.COM`
- servicio Impala (interno): `impala/impala-statestored@EXAMPLE.COM`, `impala/impala-catalogd@EXAMPLE.COM`

## Dataset de demostración

El entorno inicia con tres bases de ejemplo ya pobladas y equivalentes entre sí:

- `demo_sales_en`: modelo canónico en inglés
- `demo_vendas_ptbr`: modelo traducido a portugués de Brasil
- `demo_ventas_esmx`: modelo traducido a español de México

Cada base contiene cinco tablas relacionadas:

- EN: `customers`, `categories`, `products`, `orders`, `order_items`
- PT-BR: `clientes`, `categorias`, `produtos`, `pedidos`, `itens_pedido`
- ES-MX: `clientes`, `categorias`, `productos`, `pedidos`, `partidas_pedido`

Las tres bases de demostración se bootstrapean automáticamente en Hive:

- Hive LDAP (`10001`): lectura y exploración completas
- Hive Kerberos (`10000`): metadata y lecturas simples, como `show tables` y `select ... limit`

En los endpoints de Impala, la autenticación y la conectividad funcionan, pero los schemas de demostración todavía no aparecen de forma confiable por una incompatibilidad entre el catálogo de Impala 4.5.0 y Hive Metastore 3.1.3 (`get_dataconnectors`).

Consultas rápidas portables para Hive:

```sql
show tables in demo_sales_en;
select * from demo_vendas_ptbr.pedidos limit 5;
select * from demo_ventas_esmx.partidas_pedido limit 5;
```

## 6) Health-check rápido

```bash
./ps.sh
```

Smoke test automatizado:

```bash
./test.sh
```

Esperado:

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

Revisión de puertos:

```bash
nc -zv localhost 10000
nc -zv localhost 10001
nc -zv localhost 21050
nc -zv localhost 21051
```

## 7) Talend - conexión con usuario/contraseña (primera prueba)

En el asistente de conexión Hive (Repository):

- `Connection Mode`: `Standalone`
- `Hive Version`: `Hive 2`
- `Hadoop Version`: `Hadoop 3`
- `Server`: `localhost`
- `Port`: `10001`
- `DataBase`: `default`
- `Login`: `admin`
- `Password`: `Admin123$`
- `Additional JDBC Settings`: `auth=LDAP`

Nota: en algunas versiones de Talend, `String of Connection` es solo lectura. En ese caso, usa siempre `Additional JDBC Settings` para inyectar parámetros JDBC.

## 8) Talend - conexión con Kerberos (Hive)

### 7.1 Preparar `krb5.ini` en Windows

Archivo de ejemplo:

- [examples/windows/krb5.ini](./examples/windows/krb5.ini)

Usa una de estas opciones:

- copiar a `C:\Windows\krb5.ini` (por defecto), o
- definir variable `KRB5_CONFIG` apuntando a otra ruta.

### 7.2 Asegurar keytab en Windows

Copiar la keytab generada en el contenedor KDC:

```bash
cd /opt/cloudera-kerberos
docker cp hb-kdc:/keytabs/talend.user.keytab /tmp/talend.user.keytab
```

Después copia `/tmp/talend.user.keytab` a Windows, por ejemplo:

- `C:\Users\<TU_USUARIO>\talend.user.keytab`

### 7.3 Generar ticket Kerberos en Windows

En `cmd.exe`:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<TU_USUARIO>\talend.user.keytab talend@EXAMPLE.COM
klist
```

Esperado en `klist`: principal por defecto `talend@EXAMPLE.COM`.

### 7.4 Configurar en Talend (sin checkbox “Use Kerberos authentication”)

Si la pantalla no muestra checkbox Kerberos y la URL está bloqueada, usa:

- `Server`: `localhost`
- `Port`: `10000`
- `DataBase`: `default`
- `Login`: vacío
- `Password`: vacío
- `Additional JDBC Settings`: `auth=kerberos;principal=hive/hiveserver2.hadoop.local@EXAMPLE.COM`

Equivale a:

```text
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/hiveserver2.hadoop.local@EXAMPLE.COM
```

## 9) DBeaver

### 9.1 Hive con usuario/contraseña

En DBeaver:

- `Driver`: `Apache Hive`
- `Host`: `localhost`
- `Port`: `10001`
- `Database`: `default`
- `User name`: `admin`
- `Password`: `Admin123$`

URL JDBC de referencia:

```text
jdbc:hive2://localhost:10001/default;auth=LDAP
```

### 9.2 Hive con Kerberos

Antes de conectar en Windows:

1. copia `./talend.user.keytab` a la máquina Windows, por ejemplo `C:\Users\<TU_USUARIO>\talend.user.keytab`
2. copia [examples/windows/krb5.ini](./examples/windows/krb5.ini) a `C:\Windows\krb5.ini`, o ajusta `KRB5_CONFIG` para otra ruta
3. instala MIT Kerberos for Windows y confirma que `kinit` y `klist` estén disponibles:

Tutorial detallado de instalación:

- [docs/windows/mit-kerberos-client.es-MX.md](./docs/windows/mit-kerberos-client.es-MX.md)

```bat
where kinit
where klist
```

4. genera el ticket Kerberos:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<TU_USUARIO>\talend.user.keytab talend@EXAMPLE.COM
klist
```

En DBeaver:

- `Driver`: `Apache Hive`
- `Host`: `localhost`
- `Port`: `10000`
- `Database`: `default`
- `User name`: vacío
- `Password`: vacío

URL JDBC de referencia:

```text
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/hiveserver2.hadoop.local@EXAMPLE.COM
```

### 9.3 Impala con usuario/contraseña

En DBeaver:

- `Driver`: `Apache Impala`
- `Host`: `localhost`
- `Port`: `21051`
- `Database`: `default`
- `User name`: `admin`
- `Password`: `Admin123$`

URL JDBC de referencia:

```text
jdbc:impala://localhost:21051/default;AuthMech=3;UID=admin;PWD=Admin123$
```

### 9.4 Impala con Kerberos

Antes de conectar en Windows:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<TU_USUARIO>\talend.user.keytab talend@EXAMPLE.COM
klist
```

En DBeaver:

- `Driver`: `Apache Impala`
- `Host`: `localhost`
- `Port`: `21050`
- `Database`: `default`
- `User name`: vacío
- `Password`: vacío

URL JDBC de referencia:

```text
jdbc:impala://localhost:21050/default;AuthMech=1;KrbRealm=EXAMPLE.COM;KrbHostFQDN=impala.hadoop.local;KrbServiceName=impala
```

## 10) JDBC de referencia

Hive con usuario/contraseña:

```text
jdbc:hive2://localhost:10001/default;auth=LDAP
```

Hive con Kerberos:

```text
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/hiveserver2.hadoop.local@EXAMPLE.COM
```

Impala con usuario/contraseña:

```text
jdbc:impala://localhost:21051/default;AuthMech=3;UID=admin;PWD=Admin123$
```

Impala con Kerberos:

```text
jdbc:impala://localhost:21050/default;AuthMech=1;KrbRealm=EXAMPLE.COM;KrbHostFQDN=impala.hadoop.local;KrbServiceName=impala
```

Consultas de ejemplo para Hive:

```sql
show tables in demo_sales_en;

select * from demo_sales_en.orders limit 5;

select * from demo_vendas_ptbr.pedidos limit 5;

select * from demo_ventas_esmx.partidas_pedido limit 5;
```

## 11) Troubleshooting rápido

Error de handshake/transport en Talend:

- confirma puerto correcto (`10001` sin Kerberos, `10000` Kerberos)
- confirma `Additional JDBC Settings`
- valida si el driver JDBC de Hive/Impala está instalado en Talend

`kinit` autenticando contra AD corporativo en vez de `EXAMPLE.COM`:

- confirma que se está usando el `kinit`/`klist` del MIT Kerberos for Windows
- valida con `where kinit` y `where klist`

`PortUnreachableException` en `kinit`:

- Docker/KDC no es accesible desde la máquina Windows
- confirma `docker compose ps` y puertos `88/udp` y `88/tcp` publicados

Entorno inestable después de muchas pruebas:

```bash
cd /opt/cloudera-kerberos
docker compose down -v --remove-orphans
docker compose up -d --build
docker compose ps -a
```

Si quieres validar todo automáticamente después de cambios:

```bash
./scripts/smoke-test.sh
```

## 12) Logs útiles

```bash
docker logs -f hb-kdc
docker logs -f hb-hive-metastore
docker logs -f hb-hive-server2
docker logs -f hb-hive-server2-open
docker logs -f hb-impala-daemon
docker logs -f hb-impala-daemon-open
```

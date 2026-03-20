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
  - `kinit`/`klist` de Java (no el `klist` de Windows AD)
  - archivo `krb5.ini`
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
- `9870`: UI de NameNode
- `8020`: HDFS RPC
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

## 5) Principals y credenciales del laboratorio

Realm: `EXAMPLE.COM`

- admin: `admin/admin@EXAMPLE.COM` contraseña `admin123`
- usuario Talend: `talend@EXAMPLE.COM` contraseña `talend123`
- usuario LDAP: `admin` contraseña `Admin123$`
- servicio Hive: `hive/localhost@EXAMPLE.COM`
- servicio Impala (cliente): `impala/impala.hadoop.local@EXAMPLE.COM`
- servicio Impala (interno): `impala/impala-statestored@EXAMPLE.COM`, `impala/impala-catalogd@EXAMPLE.COM`

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
set PATH=D:\portable\java\bin;%PATH%
kinit -k -t C:\Users\<TU_USUARIO>\talend.user.keytab talend@EXAMPLE.COM
klist
```

Esperado en `klist` de Java: principal por defecto `talend@EXAMPLE.COM`.

### 7.4 Configurar en Talend (sin checkbox “Use Kerberos authentication”)

Si la pantalla no muestra checkbox Kerberos y la URL está bloqueada, usa:

- `Server`: `localhost`
- `Port`: `10000`
- `DataBase`: `default`
- `Login`: vacío
- `Password`: vacío
- `Additional JDBC Settings`: `auth=kerberos;principal=hive/localhost@EXAMPLE.COM`

Equivale a:

```text
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/localhost@EXAMPLE.COM
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
3. confirma que `kinit` y `klist` apuntan al cliente Kerberos correcto:

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
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/localhost@EXAMPLE.COM
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
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/localhost@EXAMPLE.COM
```

Impala con usuario/contraseña:

```text
jdbc:impala://localhost:21051/default;AuthMech=3;UID=admin;PWD=Admin123$
```

Impala con Kerberos:

```text
jdbc:impala://localhost:21050/default;AuthMech=1;KrbRealm=EXAMPLE.COM;KrbHostFQDN=impala.hadoop.local;KrbServiceName=impala
```

## 11) Troubleshooting rápido

Error de handshake/transport en Talend:

- confirma puerto correcto (`10001` sin Kerberos, `10000` Kerberos)
- confirma `Additional JDBC Settings`
- valida si el driver JDBC de Hive/Impala está instalado en Talend

`kinit` autenticando contra AD corporativo en vez de `EXAMPLE.COM`:

- ajusta `PATH` para usar `kinit`/`klist` de Java
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

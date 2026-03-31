# Hive 3 + Impala Dual-Mode (Kerberos + Open)

Idiomas:
- Português (este arquivo)
- [English](README.en.md)
- [Español (México)](README.es-MX.md)

Ambiente local completo para testes com Talend e JDBC, com os dois modos ativos ao mesmo tempo:

- Hive 3.1.3 com endpoint Kerberos e endpoint LDAP por usuário/senha
- Impala 4.5.0 com endpoint Kerberos e endpoint LDAP por usuário/senha
- KDC MIT Kerberos local (`EXAMPLE.COM`)
- OpenLDAP local para autenticação simples de laboratório
- HDFS + YARN
- PostgreSQL para Hive Metastore

## 1) Pré-requisitos

- Docker + Docker Compose
- Para testes Kerberos no Windows:
  - MIT Kerberos for Windows, com `kinit`/`klist`
  - arquivo `krb5.ini`
  - tutorial de instalação: [docs/windows/mit-kerberos-client.pt-BR.md](./docs/windows/mit-kerberos-client.pt-BR.md)
  - keytab do usuário de teste (`talend.user.keytab`)

## 2) Subir ambiente do zero

Scripts de conveniência na raiz:

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

Observações:

- `./up.sh` e `./recreate.sh` sincronizam automaticamente `./talend.user.keytab` na raiz do repositório
- `./up.sh` e `./recreate.sh` também exportam automaticamente os XMLs dos stacks `kerberos` e `open` para `./exported-configs`
- `./up.sh` e `./recreate.sh` também aguardam o bootstrap de dados de exemplo terminar com sucesso
- `./sync-keytab.sh` força somente essa sincronização, sem recriar serviços
- `./talend.user.keytab` fica ignorado no Git e não deve ser commitado

Equivalentes diretos:

```bash
cd /opt/cloudera-kerberos
docker compose down -v --remove-orphans
docker compose up -d --build
docker compose ps -a
```

Se quiser somente reiniciar sem apagar dados:

```bash
docker compose up -d
docker compose ps
```

## 3) Arquivos gerados localmente

- `./talend.user.keytab`: cópia local da keytab exportada pelo KDC para uso em clientes como DBeaver e Talend

## 4) Portas e endpoints

Infra:

- `88/tcp` + `88/udp`: KDC
- `749/tcp`: kadmin
- `9870`: NameNode HTTP seguro (`WebHDFS` com Kerberos)
- `9871`: NameNode HTTP open (`WebHDFS` sem Kerberos)
- `8020`: HDFS RPC seguro
- `8021`: HDFS RPC open
- `14000`: `HttpFS` com Kerberos
- `14001`: `HttpFS` sem Kerberos
- `8088`: YARN UI
- `19888`: JobHistory UI
- `9083`: Hive Metastore
- `5433`: PostgreSQL metastore

HiveServer2:

- `10000`: Hive com Kerberos
- `10001`: Hive com usuário/senha via LDAP

Impala:

- `21050`: Impala com Kerberos (HS2)
- `21051`: Impala com usuário/senha via LDAP (HS2)
- `25000`: UI Kerberos
- `25001`: UI LDAP

### Acesso HTTP ao HDFS a partir do host

Use `localhost` para testes rápidos no host local:

- `WebHDFS` com Kerberos: `http://localhost:9870/webhdfs/v1/?op=LISTSTATUS`
- `WebHDFS` sem Kerberos: `http://localhost:9871/webhdfs/v1/?op=LISTSTATUS&user.name=root`
- `HttpFS` com Kerberos: `http://localhost:14000/webhdfs/v1/?op=LISTSTATUS`
- `HttpFS` sem Kerberos: `http://localhost:14001/webhdfs/v1/?op=LISTSTATUS&user.name=root`

Exemplos com `curl`:

```bash
curl --negotiate -u : -sS "http://localhost:9870/webhdfs/v1/?op=LISTSTATUS"
curl -sS "http://localhost:9871/webhdfs/v1/?op=LISTSTATUS&user.name=root"
curl --negotiate -u : -sS "http://localhost:14000/webhdfs/v1/?op=LISTSTATUS"
curl -sS "http://localhost:14001/webhdfs/v1/?op=LISTSTATUS&user.name=root"
```

Para `WebHDFS`, operações de leitura e escrita fazem redirect para o DataNode. No host local, deixe estas portas acessíveis também:

- `9864`: DataNode HTTP do cluster Kerberos
- `9865`: DataNode HTTP do cluster open

Exemplo de escrita e leitura via `WebHDFS` open no host:

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

Exemplo equivalente via `HttpFS` open no host:

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

Se preferir usar aliases em vez de `localhost`, os hostnames internos são:

- `namenode.hadoop.local`: `WebHDFS` com Kerberos
- `namenode-open.hadoop.local`: `WebHDFS` sem Kerberos
- `httpfs.hadoop.local`: `HttpFS` com Kerberos
- `httpfs-open.hadoop.local`: `HttpFS` sem Kerberos

## 5) Principals e credenciais do laboratório

Realm: `EXAMPLE.COM`

- admin: `admin/admin@EXAMPLE.COM` senha `admin123`
- usuário Talend: `talend@EXAMPLE.COM` senha `talend123`
- usuário LDAP: `admin` senha `Admin123$`
- serviço Hive: `hive/hiveserver2.hadoop.local@EXAMPLE.COM`
- serviço Impala (cliente): `impala/impala.hadoop.local@EXAMPLE.COM`
- serviço Impala (interno): `impala/impala-statestored@EXAMPLE.COM`, `impala/impala-catalogd@EXAMPLE.COM`

## Dataset de demonstração

O ambiente sobe com três bancos de exemplo já populados e equivalentes entre si:

- `demo_sales_en`: modelo canônico em inglês
- `demo_vendas_ptbr`: modelo traduzido em português do Brasil
- `demo_ventas_esmx`: modelo traduzido em espanhol do México

Cada banco tem cinco tabelas relacionadas:

- EN: `customers`, `categories`, `products`, `orders`, `order_items`
- PT-BR: `clientes`, `categorias`, `produtos`, `pedidos`, `itens_pedido`
- ES-MX: `clientes`, `categorias`, `productos`, `pedidos`, `partidas_pedido`

Os três bancos são bootstrapados automaticamente no Hive:

- Hive LDAP (`10001`): leitura e exploração completas
- Hive Kerberos (`10000`): metadata e leituras simples, como `show tables` e `select ... limit`

Nos endpoints Impala, autenticação e conectividade estão operacionais, mas os schemas de demonstração ainda não aparecem de forma confiável por uma incompatibilidade entre o catálogo do Impala 4.5.0 e o Hive Metastore 3.1.3 (`get_dataconnectors`).

Consultas rápidas portáveis para Hive:

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

Checagem de portas:

```bash
nc -zv localhost 10000
nc -zv localhost 10001
nc -zv localhost 21050
nc -zv localhost 21051
```

## 7) Talend - conexão com usuário/senha (primeiro teste)

No assistente de conexão Hive (Repository):

- `Connection Mode`: `Standalone`
- `Hive Version`: `Hive 2`
- `Hadoop Version`: `Hadoop 3`
- `Server`: `localhost`
- `Port`: `10001`
- `DataBase`: `default`
- `Login`: `admin`
- `Password`: `Admin123$`
- `Additional JDBC Settings`: `auth=LDAP`

Observação: em algumas versões do Talend a `String of Connection` é somente leitura. Nesse caso, use sempre `Additional JDBC Settings` para injetar parâmetros JDBC.

## 8) Talend - conexão com Kerberos (Hive)

### 7.1 Preparar `krb5.ini` no Windows

Arquivo de exemplo:

- [examples/windows/krb5.ini](./examples/windows/krb5.ini)

Use uma das opções:

- copiar para `C:\Windows\krb5.ini` (padrão), ou
- definir variável `KRB5_CONFIG` apontando para outro caminho.

### 7.2 Garantir keytab no Windows

Copiar a keytab gerada no container KDC:

```bash
cd /opt/cloudera-kerberos
docker cp hb-kdc:/keytabs/talend.user.keytab /tmp/talend.user.keytab
```

Depois copie `/tmp/talend.user.keytab` para Windows, por exemplo:

- `C:\Users\<SEU_USUARIO>\talend.user.keytab`

### 7.3 Gerar ticket Kerberos no Windows

No `cmd.exe`:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<SEU_USUARIO>\talend.user.keytab talend@EXAMPLE.COM
klist
```

Esperado no `klist`: principal default `talend@EXAMPLE.COM`.

### 7.4 Configurar no Talend (sem checkbox “Use Kerberos authentication”)

Se a tela não mostra checkbox Kerberos e a URL é bloqueada, use:

- `Server`: `localhost`
- `Port`: `10000`
- `DataBase`: `default`
- `Login`: vazio
- `Password`: vazio
- `Additional JDBC Settings`: `auth=kerberos;principal=hive/hiveserver2.hadoop.local@EXAMPLE.COM`

Isso equivale a:

```text
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/hiveserver2.hadoop.local@EXAMPLE.COM
```

## 9) DBeaver

### 9.1 Hive com usuário/senha

No DBeaver:

- `Driver`: `Apache Hive`
- `Host`: `localhost`
- `Port`: `10001`
- `Database`: `default`
- `User name`: `admin`
- `Password`: `Admin123$`

URL JDBC de referência:

```text
jdbc:hive2://localhost:10001/default;auth=LDAP
```

### 9.2 Hive com Kerberos

Antes de conectar no Windows:

1. copie `./talend.user.keytab` para a máquina Windows, por exemplo `C:\Users\<SEU_USUARIO>\talend.user.keytab`
2. copie [examples/windows/krb5.ini](./examples/windows/krb5.ini) para `C:\Windows\krb5.ini`, ou ajuste `KRB5_CONFIG` para outro caminho
3. instale MIT Kerberos for Windows e confirme que `kinit` e `klist` estão disponíveis:

Tutorial detalhado de instalação:

- [docs/windows/mit-kerberos-client.pt-BR.md](./docs/windows/mit-kerberos-client.pt-BR.md)

```bat
where kinit
where klist
```

4. gere o ticket Kerberos:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<SEU_USUARIO>\talend.user.keytab talend@EXAMPLE.COM
klist
```

No DBeaver:

- `Driver`: `Apache Hive`
- `Host`: `localhost`
- `Port`: `10000`
- `Database`: `default`
- `User name`: vazio
- `Password`: vazio

URL JDBC de referência:

```text
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/hiveserver2.hadoop.local@EXAMPLE.COM
```

### 9.3 Impala com usuário/senha

No DBeaver:

- `Driver`: `Apache Impala`
- `Host`: `localhost`
- `Port`: `21051`
- `Database`: `default`
- `User name`: `admin`
- `Password`: `Admin123$`

URL JDBC de referência:

```text
jdbc:impala://localhost:21051/default;AuthMech=3;UID=admin;PWD=Admin123$
```

### 9.4 Impala com Kerberos

Antes de conectar no Windows:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<SEU_USUARIO>\talend.user.keytab talend@EXAMPLE.COM
klist
```

No DBeaver:

- `Driver`: `Apache Impala`
- `Host`: `localhost`
- `Port`: `21050`
- `Database`: `default`
- `User name`: vazio
- `Password`: vazio

URL JDBC de referência:

```text
jdbc:impala://localhost:21050/default;AuthMech=1;KrbRealm=EXAMPLE.COM;KrbHostFQDN=impala.hadoop.local;KrbServiceName=impala
```

## 10) JDBC de referência

Hive com usuário/senha:

```text
jdbc:hive2://localhost:10001/default;auth=LDAP
```

Hive com Kerberos:

```text
jdbc:hive2://localhost:10000/default;auth=kerberos;principal=hive/hiveserver2.hadoop.local@EXAMPLE.COM
```

Impala com usuário/senha:

```text
jdbc:impala://localhost:21051/default;AuthMech=3;UID=admin;PWD=Admin123$
```

Impala com Kerberos:

```text
jdbc:impala://localhost:21050/default;AuthMech=1;KrbRealm=EXAMPLE.COM;KrbHostFQDN=impala.hadoop.local;KrbServiceName=impala
```

Consultas de exemplo para Hive:

```sql
show tables in demo_sales_en;

select * from demo_sales_en.orders limit 5;

select * from demo_vendas_ptbr.pedidos limit 5;

select * from demo_ventas_esmx.partidas_pedido limit 5;
```

## 11) Troubleshooting rápido

Erro de handshake/transport no Talend:

- confirme porta correta (`10001` sem Kerberos, `10000` Kerberos)
- confirme `Additional JDBC Settings`
- confira se o driver JDBC Hive/Impala está instalado no Talend

`kinit` autenticando no AD corporativo em vez de `EXAMPLE.COM`:

- confirme que o `kinit`/`klist` do MIT Kerberos for Windows está sendo usado
- valide com `where kinit` e `where klist`

`PortUnreachableException` no `kinit`:

- Docker/KDC não está acessível da máquina Windows
- confirme `docker compose ps` e portas `88/udp` e `88/tcp` publicadas

Ambiente instável após muitos testes:

```bash
cd /opt/cloudera-kerberos
docker compose down -v --remove-orphans
docker compose up -d --build
docker compose ps -a
```

Se quiser validar tudo automaticamente após mudanças:

```bash
./scripts/smoke-test.sh
```

## 12) Logs úteis

```bash
docker logs -f hb-kdc
docker logs -f hb-hive-metastore
docker logs -f hb-hive-server2
docker logs -f hb-hive-server2-open
docker logs -f hb-impala-daemon
docker logs -f hb-impala-daemon-open
```

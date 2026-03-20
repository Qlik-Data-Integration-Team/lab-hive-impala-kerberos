# MIT Kerberos for Windows

Tutorial rápido para instalar el cliente Kerberos en Windows y validar `kinit`/`klist` para usarlo con DBeaver, Talend y otros clientes JDBC.

## 1) Descargar

Descarga el instalador oficial desde:

- https://web.mit.edu/kerberos/dist/

Busca la versión más reciente de `Kerberos for Windows`.

## 2) Instalar

Durante la instalación:

- mantén la instalación por defecto
- incluye las utilidades de línea de comandos
- termina el asistente normalmente

## 3) Confirmar los binarios

Abre un `cmd.exe` nuevo y ejecuta:

```bat
where kinit
where klist
```

Esperado:

- ambos comandos resuelven a la instalación del MIT Kerberos for Windows

## 4) Configurar `krb5.ini`

Copia el archivo de ejemplo del repositorio:

- [examples/windows/krb5.ini](../../examples/windows/krb5.ini)

A:

- `C:\Windows\krb5.ini`

O define:

```bat
set KRB5_CONFIG=C:\ruta\krb5.ini
```

## 5) Copiar la keytab

Usa la keytab sincronizada en la raíz del repositorio:

- `./talend.user.keytab`

Cópiala a Windows, por ejemplo:

- `C:\Users\<TU_USUARIO>\talend.user.keytab`

## 6) Generar ticket

En `cmd.exe`:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<TU_USUARIO>\talend.user.keytab talend@EXAMPLE.COM
klist
```

Esperado:

- principal por defecto `talend@EXAMPLE.COM`

## 7) Si falla

- revisa `where kinit`
- revisa `where klist`
- confirma que `C:\Windows\krb5.ini` apunta al host correcto del KDC
- no uses por error el `klist` nativo de Windows AD

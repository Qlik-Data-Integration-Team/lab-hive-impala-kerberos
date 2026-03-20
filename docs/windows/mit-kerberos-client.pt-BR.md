# MIT Kerberos for Windows

Tutorial rápido para instalar o cliente Kerberos no Windows e validar `kinit`/`klist` para uso com DBeaver, Talend e outros clientes JDBC.

## 1) Baixar

Baixe o instalador oficial em:

- https://web.mit.edu/kerberos/dist/

Procure pela versão mais recente do `Kerberos for Windows`.

## 2) Instalar

Durante a instalação:

- mantenha a instalação padrão
- instale os utilitários de linha de comando
- conclua o assistente normalmente

## 3) Confirmar os binários

Abra um `cmd.exe` novo e rode:

```bat
where kinit
where klist
```

Esperado:

- ambos os comandos resolvem para a instalação do MIT Kerberos for Windows

## 4) Configurar o `krb5.ini`

Copie o arquivo de exemplo do repositório:

- [examples/windows/krb5.ini](../../examples/windows/krb5.ini)

Para:

- `C:\Windows\krb5.ini`

Ou defina:

```bat
set KRB5_CONFIG=C:\caminho\krb5.ini
```

## 5) Copiar a keytab

Use a keytab sincronizada na raiz do repositório:

- `./talend.user.keytab`

Copie para o Windows, por exemplo:

- `C:\Users\<SEU_USUARIO>\talend.user.keytab`

## 6) Gerar ticket

No `cmd.exe`:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<SEU_USUARIO>\talend.user.keytab talend@EXAMPLE.COM
klist
```

Esperado:

- principal default `talend@EXAMPLE.COM`

## 7) Se não funcionar

- confira `where kinit`
- confira `where klist`
- confirme que `C:\Windows\krb5.ini` aponta para o host correto do KDC
- não use o `klist` nativo do Windows AD por engano

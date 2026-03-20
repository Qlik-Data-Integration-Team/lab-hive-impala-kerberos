# MIT Kerberos for Windows

Quick tutorial to install the Kerberos client on Windows and validate `kinit`/`klist` for use with DBeaver, Talend, and other JDBC clients.

## 1) Download

Download the official installer from:

- https://web.mit.edu/kerberos/dist/

Look for the latest `Kerberos for Windows` release.

## 2) Install

During installation:

- keep the default install
- include the command-line utilities
- finish the wizard normally

## 3) Confirm the binaries

Open a new `cmd.exe` and run:

```bat
where kinit
where klist
```

Expected:

- both commands resolve to the MIT Kerberos for Windows installation

## 4) Configure `krb5.ini`

Copy the example file from the repository:

- [examples/windows/krb5.ini](../../examples/windows/krb5.ini)

To:

- `C:\Windows\krb5.ini`

Or set:

```bat
set KRB5_CONFIG=C:\path\to\krb5.ini
```

## 5) Copy the keytab

Use the keytab synchronized at the repo root:

- `./talend.user.keytab`

Copy it to Windows, for example:

- `C:\Users\<YOUR_USER>\talend.user.keytab`

## 6) Generate a ticket

In `cmd.exe`:

```bat
set KRB5_CONFIG=C:\Windows\krb5.ini
kinit -k -t C:\Users\<YOUR_USER>\talend.user.keytab talend@EXAMPLE.COM
klist
```

Expected:

- default principal `talend@EXAMPLE.COM`

## 7) If it fails

- check `where kinit`
- check `where klist`
- confirm that `C:\Windows\krb5.ini` points to the correct KDC host
- do not accidentally use the native Windows AD `klist`

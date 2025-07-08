
# 🧾 Server Hardening – secure-lab

🔒 Tutti i file di configurazione, output e percorsi sono documentati in questo README. Lo script `secure-me.sh` automatizza la configurazione base del sistema.

## 📅 Fase 1 – Setup iniziale (07/07/2025)

### 🖥️ Informazioni VM
- Hostname: `secure-lab`
- Utente: `anshell`
- IP iniziale: `172.16.212.128/24`
- IP attuale: `192.168.1.5/24`
- Rete: DHCP automatico (bridged)

### ⚙️ Comandi principali eseguiti
```
sudo apt update && sudo apt upgrade -y  
sudo apt install fail2ban auditd rsyslog net-tools  
sudo ufw allow OpenSSH && sudo ufw enable
```
### 🔍 Verifica firewall
```
sudo ufw status verbose
```
**Output:**
```
Status: active  
Logging: on (low)  
Default: deny (incoming), allow (outgoing), disabled (routed)  
22/tcp (OpenSSH)           ALLOW IN    Anywhere
```
---

## 📅 Fase 2 – SSH Hardening & Fail2Ban (07/07/2025)

### 🛡️ SSH Configurazione

- Accesso root disabilitato: `PermitRootLogin no`
- Accesso via chiave pubblica (AuthorizedKeysFile abilitato)
- Accesso via password temporaneamente attivo per test Fail2Ban

File usati:
- `/etc/ssh/sshd_config`: lasciato di default
- `/etc/ssh/sshd_config.d/50-cloud-init.conf`:  contenuto iniziale commentato: `#PasswordAuthentication yes `


- `/etc/ssh/sshd_config.d/99-secure.conf` (aggiunto):
  ```
  PermitRootLogin no  
  PasswordAuthentication yes  
  PubkeyAuthentication yes  
  KbdInteractiveAuthentication no  
  UsePAM yes
  ```
  
### 👤 Utente
```
cat /etc/passwd | grep '/home'  
→ anshell:x:1000:1000:anshell:/home/anshell:/bin/bash
```

### 🧱 Fail2Ban configurazione
File: `/etc/fail2ban/jail.local`
```
[sshd]  
enabled = true  
port = ssh  
filter = sshd  
logpath = /var/log/auth.log  
maxretry = 3  
findtime = 600  
bantime = 600
```
**Test**: da Termux → 3 tentativi falliti = IP bannato

**Verifica stato:** ```sudo fail2ban-client status sshd```
→ IP bannato, regole attive

**Log:** ```sudo journalctl -u fail2ban --no-pager --since "10 minutes ago"```
→ conferma funzionamento

---

## 📅 Fase 3 – Logging con auditd (07/07/2025)

### 📁 File monitorato 
```/home/anshell/segreto.txt```

### 🛠️ Configurazione auditd

```sudo auditctl -w /home/anshell/segreto.txt -p rwxa -k test_file_access```

**Verifica:**
```sudo auditctl -l```  
→ `-w /home/anshell/segreto.txt -p rwxa -k test_file_access`

### 📝 Test auditd
Modificato `segreto.txt` con `nano`, `cat`, ecc.  

Visualizzato evento con:
```sudo ausearch -k test_file_access```

Estratto esempio:
```type=SYSCALL msg=audit(...) comm="cat" exe="/usr/bin/cat" key="test_file_access"```

---


## 📅 Fase 4 – Accesso SSH con chiavi firmate da CA (08/07/2025)

### 🔐 Obiettivo
Rendere l’accesso SSH possibile **solo tramite chiavi firmate** da una CA, disabilitando password e authorized_keys.

### 🗝️ Generazione chiavi e firma

Le chiavi per l’accesso vengono gestite così:
- La **CA (Certification Authority)** firma le chiavi utente → file `ssh_ca` e `ssh_ca.pub`
- Ogni utente genera la **propria coppia di chiavi** (es. `user_key` + `user_key.pub`)
- Solo la chiave firmata (`user_key-cert.pub`) sarà accettata dal server

Creazione CA:
`ssh-keygen -f ~/.ssh/ca/ssh_ca -C "CA SSH"`

Output:
- ssh_ca          (chiave privata della CA tenuta offline o protetta)
- ssh_ca.pub	(chiave pubblica da caricare sul server (in TrustedUserCAKeys)

Firma della chiave utente:
`ssh-keygen -s ~/.ssh/ca/ssh_ca -I anshell_cert -n anshell -V +52w ~/.ssh/user_key.pub`

Risultato:
`~/.ssh/user_key-cert.pub` 

> **Nota:** File usato insieme alla `user_key` privata per accedere al server.

Per collegarsi al server:
`ssh -i ~/.ssh/user_key -o CertificateFile=~/.ssh/user_key-cert.pub anshell@192.168.1.5`

> **Nota:** Si può omettere `-o CertificateFile=~/.ssh/user_key-cert.pub` se il certificato si trova nella stessa cartella della chiave firmata da usare.


### 🛠️ Configurazione server

Copiare la chiave pubblica CA sul server:

- Client:

	`sudo scp ~/.ssh/ca/ssh_ca.pub anshell@192.168.1.5:/tmp/ssh_ca.pub`

- Server:
	```
	sudo mkdir -p /etc/ssh/ca
	sudo mv /tmp/ssh_ca.pub /etc/ssh/ca/
	```

Configurazione SSH (file `/etc/ssh/sshd_config.d/99-secure.conf`):
```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
TrustedUserCAKeys /etc/ssh/ca/ssh_ca.pub
AuthorizedKeysFile none
KbdInteractiveAuthentication no
UsePAM yes
```

### 🧪 Test eseguiti

- Connessione con chiave NON firmata → rifiutata
- Connessione con chiave FIRMATA → accettata

**Verifica** log server: `journalctl -u ssh`

Output esempio:
```
Jul 08 13:13:44 secure-lab sshd[4190]: Accepted publickey for anshell from 192.168.1.10 port 45814 ssh2: ED25519-CERT SHA256:z91N96ksU7JlCO24cy6bdxV9SOsCsNTtQhi30doSNnI ID user_key_identity (serial 0) CA ED25519 SHA256:9qYzrxsq79Ck2ovcTxk5VZ5UD+PEmGuys7h794ZEwsE
Jul 08 13:13:44 secure-lab sshd[4190]: pam_unix(sshd:session): session opened for user anshell(uid=1000) by anshell(uid=0)
```

---

## 📸 Snapshot

🧊 **01-clean-setup** 
- Ubuntu aggiornato
- SSH attivo
- UFW abilitato
- root disabilitato

🧊 **02-secure-base-config**  
- SSH hardening base
- Fail2Ban attivo
- Test fallimento eseguito

🧊 **03-auditd-file-monitoring**
- auditd monitor file attivo
- Test su segreto.txt completato

🧊 **04-ssh-ca-auth**  
- Accesso consentito solo con chiavi firmate da CA
- authorized_keys ignorato

---

## 🗂️ File chiave

- `secure-me.sh` – script di hardening automatizzato
- `/etc/ssh/sshd_config.d/99-secure.conf` – configurazione definitiva SSH
- `/etc/fail2ban/jail.local` – configurazione base fail2ban
- `/home/[utente]/segreto.txt` – file monitorato
- `~/ssh_ca.pub` – chiave pubblica della CA (server)
- `~/.ssh/user_key-cert.pub` – chiave firmata (client)

---

## ✅ Obiettivi del progetto

- Sistema: Installazione VM e strumenti di rete/sicurezza (UFW, net-tools, ecc.)
- SSH: Hardening accessi, disabilitazione root, rimozione password, uso CA
- Fail2Ban: Protezione contro tentativi di accesso SSH con blocco IP
- Logging: Monitoraggio file con auditd, attivazione rsyslog
- Scripting: Script secure-me.sh per automatizzare le configurazioni iniziali
- Chiavi CA: Accesso SSH permesso solo tramite chiavi firmate da una Certification Authority
- Documentazione: README con test, configurazioni, spiegazioni e snapshot

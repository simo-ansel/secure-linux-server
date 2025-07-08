#!/bin/bash

set -e

echo "[*] Aggiorno sistema..."
sudo apt update && sudo apt upgrade -y

echo "[*] Installo pacchetti essenziali..."
sudo apt install -y openssh-server ufw fail2ban auditd rsyslog

# Creazione utente
read -p "Inserisci il nome utente da creare (minuscolo): " username
username=$(echo "$username" | tr '[:upper:]' '[:lower:]')

if id "$username" &>/dev/null; then
  echo "[*] Utente $username già esistente."
else
  sudo adduser --disabled-password --gecos "" "$username"
  echo "[*] Utente $username creato."
fi

# Configuro SSH
echo "[*] Configurazione SSH..."
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Configuro UFW
echo "[*] Configurazione UFW (firewall)..."
sudo ufw allow OpenSSH
sudo ufw --force enable

# Configuro Fail2Ban
if [ ! -f /etc/fail2ban/jail.local ]; then
  echo "[*] Creo configurazione Fail2Ban jail.local..."
  sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 600
EOF
fi

sudo systemctl restart fail2ban

# Setup file segreto e auditd
segreto="/home/$username/segreto.txt"
sudo touch "$segreto"
sudo chown "$username":"$username" "$segreto"

echo "[*] Configurazione auditd per monitorare $segreto..."
sudo auditctl -w "$segreto" -p rwxa -k test_file_access

# Configurazione base rsyslog (già installato)
echo "[*] Configurazione rsyslog..."
sudo systemctl restart rsyslog

echo "[*] Setup completato!"
echo "Utente creato: $username"
echo "File segreto: $segreto"
echo "Firewall UFW attivo, SSH protetto."
echo "Fail2Ban attivo con regole standard."
echo "Auditd monitoraggio file segreto attivo."
echo "rsyslog attivo e funzionante."

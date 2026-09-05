# Honeypot — Terraform modul

Vytváří minimální honeypot v účtu Workload: EC2 instance s otevřeným
SSH portem, bez key pair, bez IAM role. Cíl: nechat GuardDuty zachytit
reálné (ne sample) recon/brute-force nálezy z internetu.

## Předpoklady

1. Nainstalovaný [Terraform](https://developer.hashicorp.com/terraform/install) (>= 1.5)
2. Nainstalovaný a nakonfigurovaný AWS CLI
3. AWS CLI profil pro Workload account:

```powershell
aws configure --profile vl-workload
```

Zadej Access Key / Secret Key pro Workload account (nebo nastav SSO
profil, pokud máš IAM Identity Center už zapojený).

## Spuštění

```powershell
cd terraform/workload_sandbox

# Stáhne AWS provider
terraform init

# Ukáže, co se vytvoří — zkontroluj před apply
terraform plan

# Vytvoří honeypot
terraform apply
```

Terraform se zeptá na potvrzení (`yes`) před vytvořením zdrojů.

## Po vytvoření

- Zkontroluj `public_ip` output — to je adresa, na kterou míří honeypot
- Sleduj GuardDuty Findings v Security accountu (delegated admin) —
  první skenovací pokusy typicky přijdou během hodin
- Nálezy automaticky poputují přes existující pipeline (EventBridge →
  Lambda → Bedrock → DynamoDB + SNS) beze změny kódu

## Úklid — DŮLEŽITÉ

Instance má nastavený OS-level auto-shutdown (`shutdown -h +N minut`,
default 3 dny) jako bezpečnostní pojistku — ale to jen **vypne**
instanci (stav "stopped"), nesmaže ji. EBS volume dál běží a generuje
malé náklady.

Pro úplné smazání všech zdrojů (instance, security group):

```powershell
terraform destroy
```

Potvrď `yes`. Tohle je i způsob, jak honeypot **kdykoliv okamžitě
zastavit**, ne jen čekat na auto-shutdown.

## Náklady

- EC2 `t3.micro`: free tier eligible (750 hod/měsíc)
- EBS volume (default 8GB gp3): pár centů/měsíc i po zastavení instance
- Žádné další služby vytvořeny tímto modulem

## Bezpečnostní poznámky (pro ADR)

- Žádný SSH key pair → i úspěšný TCP handshake na port 22 nikoho
  nepustí dovnitř
- Žádná IAM role → i teoretická kompromitace nezíská AWS API přístup
- Security group povoluje jen port 22 dovnitř, nic jiného
- Outbound ponechán otevřený záměrně — pokud by instance přesto
  komunikovala ven, chceme to zachytit jako GuardDuty finding

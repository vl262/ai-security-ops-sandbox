# ADR-004: Honeypot design a rozsah nasazení přes Terraform

**Status:** Accepted
**Datum:** 2026-09-05
**Autor:** Vlad

## Context

Fáze 1-3 (governance, detekce, AI triage) byly ověřeny výhradně na
GuardDuty sample findings — syntetická data, která ověří funkčnost
pipeline, ale neodrážejí skutečné chování útočníků. Cílem Fáze B je
získat autentická data z reálného internetového provozu, aniž by
projekt nesl zbytečné bezpečnostní nebo finanční riziko.

Souběžně bylo potřeba rozhodnout, jak zavést Terraform do projektu,
když zbytek architektury (Organizations, GuardDuty/Security Hub
delegace, EventBridge, Lambda, DynamoDB, SNS, CloudTrail) už existuje
a byl nastaven ručně přes konzoli.

## Decision

### Honeypot design

Minimální EC2 instance (`t3.micro`, Amazon Linux 2023) ve Workload
účtu, s bezpečnostními mantinely zabudovanými přímo do Terraform kódu:

- **Žádný SSH key pair** (`key_name` neuvedeno) — i úspěšný TCP
  handshake na port 22 nikoho nepustí dovnitř
- **Žádná IAM role** (`iam_instance_profile` neuvedeno) — teoretická
  kompromitace instance nezíská žádný AWS API přístup
- **Security group s jediným ingress pravidlem** — port 22 z
  `0.0.0.0/0`, nic jiného dovnitř
- **Outbound ponechán otevřený** — pokud by instance přesto
  komunikovala ven, chceme to zachytit jako GuardDuty finding, ne
  to blokovat na síťové úrovni
- **OS-level auto-shutdown** (`shutdown -h +N` v user_data, default
  3 dny) jako pojistka navíc k AWS Budgets alertům — vypíná instanci
  (stav "stopped"), nemaže ji; úplné smazání vyžaduje `terraform destroy`
- **Žádná aplikace ani web server** — GuardDuty detekuje na síťové/
  systémové úrovni (port scanning, brute-force pokusy), aplikační
  vrstva není pro tento cíl (síťový recon) potřeba

### Rozsah Terraformu — jen nové zdroje, ne import existující infrastruktury

Zvolena varianta "Terraform pro nové zdroje" místo `terraform import`
na existující ručně vytvořenou infrastrukturu:

- Honeypot je **první zdroj v projektu, který od počátku neexistoval**
  — ideální kandidát pro čistý Terraform lifecycle (create → manage →
  destroy) bez rizika spojeného s importem
- Zbytek architektury (Organizations, delegovaná administrace,
  AI triage pipeline) zůstává prozatím spravován ručně

## Alternatives considered

| Alternativa | Proč zamítnuta |
|---|---|
| Nasadit i zbytek existující infrastruktury přes `terraform import` | Import organizačních resources (Organizations, delegovaná administrace) je komplikovaný nebo nepodporovaný; riziko omylem poškodit živé, funkční prostředí bez odpovídajícího přínosu pro portfolio účel |
| Honeypot s reálnou zranitelnou aplikací (např. DVWA) místo holé instance | Výrazně vyšší riziko a složitost setupu; cílem Fáze B je síťová detekce (recon, brute-force), ne aplikační útoky — holá instance k tomu stačí |
| SSH key pair s reálným, ale slabým heslem (pro "chycení" skutečného přihlášení) | Zbytečné riziko — i honeypot bez záměru poskytnout skutečný přístup má bezpečnostní hodnotu jen v detekci pokusů, ne v tom nechat někoho dovnitř |
| Ponechat instanci běžet bez časového omezení | Bez auto-shutdown pojistky by honeypot mohl běžet neomezeně a zvyšovat riziko i náklady bez aktivního rozhodnutí |

## Consequences

**Pozitiva:**
- Bezpečnostní mantinely jsou vynucené přímo v kódu (ne jen v hlavě/
  poznámkách) — kdokoliv spustí `terraform apply` znovu, dostane
  stejně bezpečnou konfiguraci
- Čistý Terraform lifecycle bez importu — nižší riziko chyby
- `terraform destroy` dává okamžitou, spolehlivou cestu k úplnému
  úklidu, nezávisle na auto-shutdown timeru

**Trade-offy / rizika:**
- Projekt teď má **smíšenou správu** — část infrastruktury Terraform,
  část ruční — což je běžný přechodný stav u brownfield projektů, ale
  vyžaduje jasnou dokumentaci, co je spravováno čím (viz README)
  aby nedošlo k záměně
- OS-level shutdown (ne terminate) znamená, že EBS volume dál generuje
  malé náklady i po auto-shutdown, dokud neproběhne `terraform destroy`

**Co to vyžaduje do budoucna:**
- Sledovat GuardDuty findings ze skutečného provozu (ne sample) a
  ověřit, že AI triage pipeline zpracovává reálná data stejně
  spolehlivě jako syntetická
- Rozhodnout o rozšíření Terraformu na další moduly
  (`organization/`, `security_hub/`, `ai_triage_pipeline/`) jako
  referenční implementaci (bez importu proti živým účtům)
- Po dokončení testování Fáze B spustit `terraform destroy` a
  zdokumentovat zjištění (typy a četnost reálných nálezů)

## Related

- ADR-001 — Delegovaný administrátor pro GuardDuty a Security Hub
- `terraform/workload_sandbox/` — implementace popsaná v tomto ADR

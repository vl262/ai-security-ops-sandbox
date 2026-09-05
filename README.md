# AI-Assisted Security Operations Sandbox

Multi-account AWS architektura pro centralizovanou bezpečnostní detekci
s AI triage vrstvou (Amazon Bedrock). Portfolio projekt zaměřený na
AWS Organizations governance, delegovanou administraci a automatizované
zpracování bezpečnostních nálezů.

## Cíl projektu

- Prakticky si osahat koncepty AWS Certified Solutions Architect Professional
  (SAP-C02) a AWS Certified Security Specialty (SCS-C03) — multi-account
  governance, delegovaná administrace, centralizovaná detekce
- Vybudovat portfolio s ověřitelnými artefakty (IaC, diagramy, ADRs,
  Well-Architected review)

## Architektura

![Architecture diagram](docs/architecture.svg)

Tři AWS účty pod jednou AWS Organization:

| Účet | Role |
|---|---|
| **Management** | AWS Organizations, SCPs, IAM Identity Center, Budgets |
| **Security** | Delegovaný administrátor pro GuardDuty + Security Hub; hostí AI triage pipeline |
| **Workload** | Sandbox zdroje, kde vznikají bezpečnostní nálezy |

### Detekční a AI pipeline (Security account)

```
GuardDuty/Security Hub finding
   → EventBridge rule
   → Lambda (glue kód)
   → Bedrock (Claude Haiku) – shrnutí, závažnost, remediace
   → DynamoDB (log) + SNS (notifikace)
```

### Fáze B — Honeypot (Workload account)

Minimální EC2 instance (`t3.micro`, Amazon Linux 2023) s otevřeným
portem 22 pro celý internet, bez SSH klíče a bez IAM role (viz
ADR-004). Cíl: získat autentická GuardDuty data z reálného
internetového provozu místo jen syntetických sample findings.

**Jak boti najdou konkrétní IP adresu:** Není to náhodné uhodnutí.
Služby jako Shodan a Censys kontinuálně skenují celý IPv4 prostor
a katalogizují otevřené porty; útočné botnety pak cílí prioritně na
známé cloud-provider IP rozsahy (AWS, Azure, GCP jsou veřejně
publikované), protože pravděpodobnost nalezení zajímavého cíle je
tam vyšší než u náhodných domácích ISP rozsahů. `us-east-1` je
navíc největší a nejexponovanější AWS region, což zvyšuje rychlost
detekce. Realisticky lze čekat první skenovací pokusy v řádu hodin
od vystavení nové IP adresy.

## Tech stack

- **IaC:** Terraform
- **Detekce:** Amazon GuardDuty, AWS Security Hub, AWS Config
- **AI:** Amazon Bedrock (Claude Haiku)
- **Automatizace:** EventBridge, Lambda, DynamoDB, SNS

## Konfigurace

- **AWS Region:** `us-east-1`
  _(pozn.: GuardDuty a Security Hub delegovaná administrace i CloudWatch
  billing metriky vyžadují přítomnost v us-east-1; ostatní zdroje zatím
  drženy ve stejném regionu kvůli jednoduchosti, zvážit případné
  přesunutí blíž geograficky později a zdůvodnit v ADR)

## Známá omezení

**Bedrock throttling při hromadném testu.** Lambda škáluje horizontálně
— při náhlém přílivu velkého množství findings (např. desítky/stovky
sample findings vygenerovaných najednou) se spustí odpovídající počet
souběžných Lambda invocations, z nichž každá volá Bedrock Converse API
samostatně. To může překročit account-level rate limit modelu a vyvolat
`ThrottlingException` (`boto3` automaticky retryuje, ale i s retry lze
limit vyčerpat).

**Upřesnění (2026-09-04):** AWS Health Dashboard potvrdil souběžně
probíhající incident — zvýšená míra `503 Service Unavailable` chyb
pro Claude Haiku 4.5 v us-east-1, 6:58–7:13 AM PDT, popsaný přímo jako
"some requests to invoke this model were intermittently throttled and
returned errors" (vyřešeno AWS engineering týmem, doporučen retry
neúspěšných requestů). Časově se to shoduje s naším testem, takže
throttling byl pravděpodobně kombinací vlastního nárazového vzorce
(stovky findings najednou → souběžné Lambda invocations) **a**
paralelně probíhajícího AWS-side incidentu — ne čistě důsledek
vlastního zatížení účtu.

Pro tento sandbox ponecháno neřešené — v reálném provozu findings
nepřichází v takto koncentrovaných dávkách. Pro produkční nasazení
by řešením bylo zařadit SQS frontu mezi EventBridge a Lambda (tlumí
nárazovou zátěž) a/nebo nastavit Lambda reserved concurrency limit,
aby počet souběžných Bedrock volání zůstal pod rate limitem.

## Struktura repa

```
├── main.tf
├── modules/
│   ├── organization/         # SCPs, OUs, Budgets
│   ├── security_hub/         # Delegated admin, GuardDuty/Security Hub
│   ├── ai_triage_pipeline/   # EventBridge, Lambda, Bedrock, DynamoDB, SNS
│   └── workload_sandbox/     # GuardDuty member, honeypot (Fáze B)
├── docs/
│   ├── adr/                  # Architecture Decision Records
│   ├── architecture.svg
│   └── well-architected/     # Baseline a finální review
└── README.md
```

## Jak spustit

_TODO: doplnit po prvním funkčním `terraform apply` — providers per účet,
potřebné proměnné, prerekvizity._

## Stav projektu / timeline

| Datum | Milník |
|---|---|
| 2026-09-03 | Založena AWS Organization, Management account |
| 2026-09-03 | Security a Workload účty vytvořeny |
| 2026-09-03 | GuardDuty aktivováno (30denní free trial) |
| 2026-09-03 | Security Hub aktivováno (30denní free trial) |
| 2026-09-03 | Delegovaný administrátor nastaven (GuardDuty, Security Hub) |
| 2026-09-03 | Workload účet zapojen do GuardDuty i Security Hub scope (aktivace Security Hub musela proběhnout lokálně v účtu, ne centrálně ze Security accountu) |
| 2026-09-03 | Cesta A ověřena end-to-end: GuardDuty sample findings vygenerovány (434) a úspěšně agregovány do Security Hub (942) |
| 2026-09-04 | EventBridge rule `vl-security-hub-findings-to-log` vytvořena a ověřena — Security Hub findings se propisují do CloudWatch Logs (100+ log streamů potvrzeno) |
| 2026-09-04 | Lambda `vl-security-hub-triage` vytvořena, napojena jako druhý EventBridge target, ověřeno úspěšné spouštění (desítky invocations, 0 failed; ~2ms duration, 39 MB max memory při 128 MB alokaci) |
| 2026-09-04 | Model access pro Claude Haiku 4.5 aktivován (use case form submitted, okamžité schválení); ověřeno v Bedrock Playground |
| 2026-09-04 | AI triage pipeline funkční end-to-end: GuardDuty → Security Hub → EventBridge → Lambda → Bedrock (Claude Haiku 4.5) potvrzeno reálným AI-generovaným shrnutím v CloudWatch Logs |
| 2026-09-04 | Zjištěno: `ThrottlingException` na Bedrock Converse API při hromadném testu (stovky sample findings najednou → Lambda škáluje horizontálně → desítky souběžných Bedrock volání překročí account-level rate limit). Neřešeno — pro sandbox účel akceptováno, viz poznámka níže |
| 2026-09-04 | DynamoDB tabulka `vl-security-findings` vytvořena (on-demand, PK `FindingId` + SK `ProcessedAt`); Lambda rozšířena o zápis AI triage výsledků; ověřeno kompletním záznamem v tabulce (AI summary, severity, timestamps, sample flag) |
| 2026-09-04 | SNS topic `vl-security-findings-alerts` vytvořen, e-mail subscription potvrzena, Lambda rozšířena o `sns.publish()`; **kompletní pipeline ověřena end-to-end** — GuardDuty → Security Hub → EventBridge → Lambda → Bedrock → DynamoDB + SNS, potvrzeno doručeným e-mailem s AI shrnutím nálezu |
| 2026-09-04 | CSPM baseline review proveden (Security Hub Posture management, 406 nálezů). Root MFA ověřeno, IAM Manager MFA doplněno, SSM public sharing block opraven. CloudTrail identifikován jako chybějící součást architektury — viz ADR-003 |
| 2026-09-04 | CloudTrail `vl-organization-trail` vytvořen — multi-region, organizational trail pokrývající všechny 3 účty, Management events Read+Write, SSE-S3 šifrování. Poslední High-severity CSPM nález z ADR-003 vyřešen |
| 2026-09-05 | Terraform poprvé nasazen — modul `workload_sandbox` (honeypot EC2 + security group) ve Workload účtu. První živý IaC-spravovaný zdroj v projektu; zbytek architektury zůstává ručně nastavený (viz ADR-004 k rozhodnutí o rozsahu Terraformu) |
| 2026-09-05 | Fáze B zahájena: honeypot EC2 (`t3.micro`, Amazon Linux 2023, žádný SSH klíč, žádná IAM role) nasazen ve Workload účtu, veřejná IP `18.205.237.67` přiřazena, port 22 otevřený pro internet. Launch time: 2026-09-05 14:44 CEST → OS-level auto-shutdown naplánován na **2026-09-08 14:44 CEST** (stopped, ne terminated — úplné smazání vyžaduje `terraform destroy`). Čeká se na první reálné GuardDuty nálezy |

### Struktura Security Hub finding eventu (pro Lambda parsing)

Ověřeno na reálném (sample) eventu z EventBridge. Klíčové cesty v JSON,
které bude Lambda potřebovat pro AI triage:

| Pole | Cesta v JSON | Příklad |
|---|---|---|
| Název nálezu | `detail.findings[0].Title` | "A phishing domain name was queried by EC2 instance..." |
| Závažnost | `detail.findings[0].Severity.Label` | `HIGH` |
| Popis | `detail.findings[0].Description` | Volný text popisu incidentu |
| Účet | `detail.findings[0].AwsAccountId` | 12místné account ID |
| Typ zdroje | `detail.findings[0].Resources[0].Type` | `AwsEc2Instance` |
| Zdroj nálezu | `detail.findings[0].ProductName` | `GuardDuty` |
| Je to sample? | `detail.findings[0].Sample` | `true` / `false` |
| Odkaz do konzole | `detail.findings[0].SourceUrl` | přímý link na finding v GuardDuty |

`detail.findings` je pole — Security Hub může v jednom eventu poslat víc
nálezů najednou, Lambda musí iterovat, ne předpokládat jen jeden prvek.

### DynamoDB schéma (`vl-security-findings`)

| Atribut | Typ | Účel |
|---|---|---|
| `FindingId` (Partition key) | String | Unikátní ID nálezu (`detail.findings[0].Id`) |
| `ProcessedAt` (Sort key) | String (ISO 8601) | Kdy Lambda finding zpracovala — umožňuje historii při opakovaných update eventech |
| `FindingCreatedAt` | String (ISO 8601) | Kdy finding vznikl (`CreatedAt` z originálního eventu) — rozdíl vůči `ProcessedAt` = latence pipeline |
| `Title`, `Severity`, `AccountId` | String | Základní metadata nálezu |
| `AISummary` | String | Výstup Bedrock triage |
| `Sample` | Boolean | Odlišuje testovací sample findings od reálných |

Table class: **Standard** (ne Standard-IA — nízký objem dat, časté zápisy
relativně k velikosti, IA se nevyplatí). Billing mode: **on-demand**.

### SNS notifikace (`vl-security-findings-alerts`)

Standard topic (ne FIFO — netřeba garantované pořadí/deduplikace).
E-mail subscription, potvrzena ručně přes odkaz z AWS potvrzovacího
e-mailu. Lambda po zápisu do DynamoDB volá `sns.publish()` se stejným
AI shrnutím — subject obsahuje severity a title nálezu, body obsahuje
plný AI summary.

### IAM oprávnění Lambda role — shrnutí

Lambda execution role má tři samostatné inline policies (least-privilege,
jedna služba = jedna policy, snadno auditovatelné):

| Policy | Akce | Resource |
|---|---|---|
| `bedrock-invoke-inline` | `bedrock:InvokeModel` | `*` (cross-region inference profile) |
| `dynamodb-putitem-inline` | `dynamodb:PutItem` | ARN konkrétní tabulky |
| `sns-publish-inline` | `sns:Publish` | ARN konkrétního topicu |

## Náklady

_TODO: doplnit reálný cost breakdown po prvním měsíci provozu —
cílový rozpočet $190 (AWS Free Tier credit)._

### Security Hub v2 — přepracovaný cenový model (zjištěno 09/2026)

Security Hub nedávno přešel na nový model, kde je **Essentials plan
povinný a nerozdělitelný** — zahrnuje vulnerability management (Inspector),
posture management (CSPM) i CIEM dohromady. Jednotlivé capabilities
(vulnerability/posture management) **nejde vypnout samostatně** —
lze vypnout jen network reachability scanning zvlášť.

**Cenový mechanismus (po 30denním trialu):** $3.75 / resource unit / měsíc.

| Typ zdroje | Přepočet na 1 resource unit |
|---|---|
| EC2 instance | 1 |
| Lambda funkce | 12 funkcí |
| ECR container image | 18 images |
| IAM user/role | 125 |

**Dopad na tenhle projekt:** zanedbatelný. Bez EC2 instancí a s jednotkami
IAM rolí napříč účty je aktuální spotřeba zlomek jednoho resource unitu
(řádově centy/měsíc). Až přibude honeypot EC2 (Fáze B), počítat s
**~$3.75/měsíc paušálně za tu jednu instanci** (prorated podle aktivních
hodin), bez ohledu na její velikost nebo dobu běhu v rámci měsíce.

GuardDuty threat detection (CloudTrail/VPC Flow/DNS analýza) je oddělený
add-on mimo Security Hub Essentials trial, se svým vlastním 30denním
trialem a odděleným cenováním (per-event, per-GB) — u sandboxu s nízkým
objemem dat rovněž řádově centy.

**Potvrzeno napříč účty:** stejné chování (automatická aktivace Essentials
bundle při zapnutí Security Hub) nastává **v každém členském účtu zvlášť**
— ověřeno při zapojování Workload účtu do scope. Resource-unit pricing
se tedy počítá per účet, ne agregovaně za celou organizaci. Vzhledem
k minimálnímu počtu zdrojů v obou účtech (Security, Workload) zůstává
dopad zanedbatelný.

→ Rozhodnutí ponechat Essentials capabilities zapnuté (nelze vypnout,
náklady zanedbatelné) zdokumentovat jako ADR.

## Architektonická rozhodnutí

Klíčová rozhodnutí a jejich zdůvodnění viz [`docs/adr/`](docs/adr/).

## Well-Architected reviews

Baseline a finální review viz [`docs/well-architected/`](docs/well-architected/).

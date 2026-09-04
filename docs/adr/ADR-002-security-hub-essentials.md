# ADR-002: Přijetí nerozdělitelného Security Hub Essentials plánu

**Status:** Accepted
**Datum:** 2026-09-03
**Autor:** Vlad

## Context

Při onboardingu AWS Security Hub (delegovaný administrátor v Security
účtu) AWS automaticky nabídl a po potvrzení aktivoval kompletní sadu
"Essential capabilities" — vulnerability management (Amazon Inspector),
posture management (Security Hub CSPM) a CIEM (cloud infrastructure
entitlement management) — nad rámec toho, co bylo pro projekt plánováno
(jen agregace GuardDuty nálezů).

Původní záměr byl aktivovat pouze základní finding aggregation a
vyhnout se dodatečným placeným capabilities, dokud pro ně nebude
v projektu konkrétní využití (viz nákladová varování z rozboru
architektury, který projekt provázel od začátku).

Po ověření v AWS konzoli a oficiální dokumentaci se ukázalo, že
Security Hub prošel přepracováním cenového modelu (Security Hub v2):
Essentials plan je nyní **povinný základ** pro jakoukoliv funkčnost
Security Hub a jednotlivé capabilities v něm (vulnerability management,
posture management, CIEM) **nelze deaktivovat samostatně** — lze vypnout
pouze network reachability scanning jako jedinou volitelnou komponentu.

## Decision

Ponecháváme Security Hub Essentials plan aktivní se všemi zahrnutými
capabilities (vulnerability management, posture management, CIEM),
protože je nelze vypnout jednotlivě a jejich deaktivace by vyžadovala
úplné zrušení Security Hub jako služby — což by rozbilo celou
architekturu (delegovaná administrace, agregace GuardDuty nálezů,
navazující EventBridge → Lambda → Bedrock pipeline).

Network reachability scanning, jediná oddělitelná komponenta,
zůstává **vypnutý** — nemá pro sandbox bez veřejně vystavených
zdrojů (zatím) žádnou hodnotu.

Stejné chování (automatická aktivace Essentials bundle) bylo potvrzeno
i při zapojování **Workload účtu** do Security Hub scope — jde tedy
o vlastnost služby uplatňovanou per účet, ne jen specifikum
delegovaného administrátora.

## Alternatives considered

| Alternativa | Proč zamítnuta |
|---|---|
| Nepoužívat Security Hub, jen samotný GuardDuty | Ztráta centrální agregace a normalizace nálezů (ASFF formát), na kterou navazuje zbytek pipeline; Security Hub je architektonicky klíčový pro cíl projektu |
| Zrušit Security Hub a znovu aktivovat jen s minimální konfigurací | Essentials bundle je vynucený při jakékoliv aktivaci — stejný výsledek, zbytečná práce navíc |
| Přesunout projekt na starší Security Hub (v1) bez nového cenového modelu | Není dlouhodobě udržitelné řešení pro portfolio projekt; staví na zastaralém modelu, který AWS aktivně nahrazuje |

## Consequences

**Pozitiva:**
- Žádná dodatečná konfigurační práce potřeba — capabilities jsou
  aktivní automaticky a bez nutnosti explicitního setupu
- CIEM nálezy (nevyužitá oprávnění IAM rolí) jsou bonus obsah pro
  budoucí Well-Architected review (Security pilíř, least-privilege)
- Cenový dopad je u tohoto sandboxu zanedbatelný (viz níže)

**Trade-offy / rizika:**
- Ztráta jemné kontroly nad tím, co přesně běží — nelze mít "jen
  GuardDuty agregaci" bez zbytku bundle
- Po vypršení 30denního trialu se capabilities začnou účtovat
  (i když v tomto rozsahu zanedbatelně) — nutnost sledovat datum
  konce trialu v projektové timeline

**Náklady (resource-unit pricing, $3.75/unit/měsíc po trialu):**
- Aktuální stav (žádné EC2, jednotky IAM rolí): zlomek 1 resource
  unitu → řádově centy/měsíc
- Po přidání honeypot EC2 (Fáze B): +1 resource unit (~$3.75/měsíc,
  prorated podle aktivních hodin) bez ohledu na velikost instance

**Co to vyžaduje do budoucna:**
- Zaznamenat datum konce Security Hub Essentials trialu do README
  timeline (odděleně od GuardDuty trialu — běží nezávisle)
- Při plánování Fáze B (honeypot) počítat s +$3.75/měsíc v rozpočtu

## Related

- [Security Hub Pricing (AWS)](https://aws.amazon.com/security-hub/pricing/)
- ADR-001 — Delegovaný administrátor pro GuardDuty a Security Hub
- `docs/well-architected/` — CIEM nálezy jako vstup do budoucího review

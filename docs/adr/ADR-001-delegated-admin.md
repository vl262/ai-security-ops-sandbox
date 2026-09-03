# ADR-001: Delegovaný administrátor pro GuardDuty a Security Hub

**Status:** Accepted
**Datum:** 2026-09-03
**Autor:** Vlad

## Context

Projekt staví na třech AWS účtech pod jednou AWS Organization
(Management, Security, Workload) s cílem centralizovat bezpečnostní
detekci a nálezy z celé organizace na jedno místo, odkud je dále
zpracovává AI triage pipeline (EventBridge → Lambda → Bedrock).

GuardDuty i Security Hub podporují dva základní modely správy napříč
organizací:
1. Správa přímo z Management accountu
2. Delegovaná administrace na vybraný členský účet

Management account má podle doporučení AWS zůstat bez vlastních
resources/workloadů (potvrzeno i přímo v AWS konzoli při zakládání
organizace — "We recommend to use an account with no resources or
workloads"). Navíc Service Control Policies (SCP) se na Management
account vůbec nevztahují, takže jakákoliv bezpečnostní služba běžící
přímo tam by fungovala mimo vlastní guardrail systém projektu.

## Decision

GuardDuty i Security Hub jsou delegované na **Security account**
jako jednoho společného delegovaného administrátora pro obě služby.
Delegace byla provedena z Management accountu (jediné místo, odkud
lze delegaci nastavit) prostřednictvím konzolových kroků
"Delegated administrator" v nastavení obou služeb.

Security account tak funguje jako centrální "SOC" účet — sbíhají se
do něj GuardDuty nálezy, Security Hub je agreguje a normalizuje
(ASFF formát), a odtud pokračuje zbytek AI triage pipeline.

## Alternatives considered

| Alternativa | Proč zamítnuta |
|---|---|
| Správa GuardDuty/Security Hub přímo z Management accountu | Management account má zůstat bez resources; SCP se na něj nevztahují, takže by bezpečnostní služby běžely mimo guardrail systém; vyšší blast radius při případné kompromitaci nejvýsadnějšího účtu organizace |
| Samostatná správa GuardDuty per-účet bez centrální agregace | Ztráta jednotné viditelnosti napříč organizací; neodpovídalo by cíli projektu (centralizovaná detekce) ani konceptům SAP-C02/SCS-C03, které se tímto vzorem přímo zabývají |
| Různé delegované administrátory pro GuardDuty a Security Hub (dva různé účty) | Zbytečná komplikace toku dat — Security Hub agreguje findings z GuardDuty, takže oddělení delegace by ztížilo propojení bez reálného přínosu |

## Consequences

**Pozitiva:**
- Management account zůstává minimálně používaný a bez provozních
  rizik, v souladu s AWS doporučením
- Jeden jasně definovaný "SOC" účet zjednodušuje architekturu i
  navazující IAM/cross-account permission model pro AI pipeline
- Přímá demonstrace konceptu delegované administrace — klíčové téma
  SAP-C02 i SCS-C03

**Trade-offy / rizika:**
- Delegovaný administrátor má rozsáhlá oprávnění v rámci celé
  organizace pro danou službu — je potřeba mu věnovat stejnou
  pozornost jako Management accountu z hlediska přístupových práv
- Cross-account tok dat (findings z Workload do Security účtu)
  vyžaduje správně nastavená oprávnění a auto-enable pro nové členy

**Co to vyžaduje do budoucna:**
- Při přidávání dalších členských účtů (do budoucna) zajistit
  auto-enable v obou službách, aby se noví členové zapojili
  automaticky
- Zvážit cross-account role z Lambdy (assume-role do Workload účtu
  pro doplňkové detaily o zdrojích) jako rozšíření pipeline — patří
  do samostatného budoucího ADR

## Related

- ADR-002 — Přijetí nerozdělitelného Security Hub Essentials plánu
- AWS Organizations dokumentace k delegated administrator modelu

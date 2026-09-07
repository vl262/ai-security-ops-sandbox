# ADR-007: IAM oprávnění pro `terraform-cli` při provisioningu IAM rolí

**Status:** Accepted
**Datum:** 2026-09-05
**Autor:** Vlad

## Context

Při přidávání VPC Flow Logs (diagnostický nástroj — viz níže, proč
byly potřeba) bylo nutné vytvořit novou IAM roli
(`vl-honeypot-flow-logs-role`) přes Terraform. IAM uživatel
`terraform-cli`, dosud vybavený jen `AmazonEC2FullAccess`, na to
neměl oprávnění.

Přidávání chybějících permissions probíhalo iterativně — každý
`terraform apply` odhalil další jednu chybějící, dosud netušenou
akci, celkem přes šest kol:

1. `logs:CreateLogGroup`, `iam:CreateRole` (základní vytvoření)
2. `logs:DescribeLogGroups`, `iam:ListRolePolicies` (Terraform čte
   stav zpět po vytvoření, aby potvrdil přesný výsledek)
3. `logs:ListTagsForResource`, `iam:ListAttachedRolePolicies`
   (kontrola tagů a připojených managed policies)
4. `iam:ListInstanceProfilesForRole` (kontrola při destroy/recreate
   cyklu — Terraform před smazáním role ověřuje, že není použitá
   v instance profile)

Původně scoped, úzké `iam:List...`/`iam:Get...` akce byly nakonec
nahrazeny širším `iam:*`, ale **jen na ARN jedné konkrétní role**
(`vl-honeypot-flow-logs-role`), ne účet-wide.

### Proč vůbec VPC Flow Logs

Zjištěno, že GuardDuty finding typ `Recon:EC2/PortProbeUnprotectedPort`
vzniká jen pro provoz ze zdrojové IP, která je na GuardDuty vlastním
threat intelligence listu — ne pro jakékoliv sondování portu.
Oportunistické skenování z běžné, "neoznačené" IP tedy může na
honeypot reálně dorazit, aniž by GuardDuty vygeneroval jakýkoliv
finding. VPC Flow Logs poskytují nezávislé, syrové potvrzení
síťového provozu, oddělené od GuardDuty vyhodnocení.

## Decision

Použit scoped `iam:*` na jeden konkrétní role ARN, místo:
(a) hádání/hledání každé jednotlivé chybějící `List`/`Get`/`Describe`
akce zvlášť, nebo
(b) použití účet-wide `IAMFullAccess` managed policy.

Zdůvodnění: Terraform AWS provider dělá při každém `apply` (i
`destroy`/recreate) rozsáhlý refresh existujícího stavu — čte zpět
tagy, připojené policies, instance profily a další metadata, aby
měl přesný obraz reality. Tohle chování není zdokumentované jako
"co všechno resource X vyžaduje" v běžné dokumentaci jednotlivých
Terraform resources — objevuje se až prakticky, v okamžiku apply.
Scoped `iam:*` na jeden ARN je rozumný kompromis mezi bezpečností
(žádný účet-wide přístup) a praktičností (nekonečné hledání
jednotlivých read-only akcí).

## Alternatives considered

| Alternativa | Proč zamítnuta |
|---|---|
| Pokračovat v hledání jednotlivé chybějící `List`/`Describe` akce | Po 4. kole stejného vzorce (pořád jedna další chybějící read akce) přestalo být efektivní — diminishing returns oproti scoped `iam:*` |
| `IAMFullAccess` (účet-wide) na `terraform-cli` | Umožnilo by uživateli spravovat JAKOUKOLIV IAM roli v účtu, včetně potenciálně citlivějších — zbytečně široké oproti scoped alternativě |
| Vytvořit roli ručně v konzoli, ne přes Terraform | Ztratilo by to smysl celého cvičení (IaC, reprodukovatelnost) — a nekonzistentní se zbytkem přístupu k projektu |

## Consequences

**Pozitiva:**
- `terraform-cli` má teď plná oprávnění jen k jedné konkrétní,
  účelové roli — ne k IAM obecně
- Reálná, zdokumentovaná zkušenost s tím, jak se least-privilege
  IAM policy pro Terraform provisioning v praxi ladí iterativně,
  ne navrhuje dopředu z dokumentace

**Trade-offy / rizika:**
- `iam:*` na jeden ARN je pořád širší, než teoreticky nutné (obsahuje
  i akce, které Terraform nikdy nevyužije) — ale hledání přesného
  minimálního setu by vyžadovalo desítky dalších iterací bez
  odpovídajícího bezpečnostního přínosu u jednoúčelové role v sandboxu

**Co to vyžaduje do budoucna:**
- Při přidávání dalších Terraform resources vytvářejících IAM role
  očekávat podobný iterativní proces, ne se snažit odhadnout
  kompletní permission set dopředu
- Zkontrolovat VPC Flow Logs po uplynutí dostatečné doby — potvrdit,
  jestli honeypot skutečně přijímá provoz, i když GuardDuty mlčí

## Related

- ADR-004 — Honeypot design a rozsah nasazení přes Terraform
- ADR-006 — Srovnání Terraform vs. CloudFormation (podobný vzorec
  "hidden IAM dependencies" pozorován i tam, jiným směrem)
- `terraform/workload_sandbox/flow_logs.tf` — implementace

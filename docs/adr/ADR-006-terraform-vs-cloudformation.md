# ADR-006: Srovnání Terraform vs. CloudFormation (honeypot experiment)

**Status:** Accepted — informativní, CloudFormation stack po experimentu odstraněn
**Datum:** 2026-09-05
**Autor:** Vlad

## Context

Terraform byl zvolen jako primární IaC nástroj projektu (viz README —
multi-cloud relevance, širší uplatnění v job requirementech). Pro
prohloubení praktického porozumění byl stejný honeypot modul (VPC,
subnet, IGW, route table, security group, EC2 instance) přepsán do
AWS CloudFormation a nasazen paralelně, aby šlo přímo porovnat
zkušenost s oběma nástroji na identickém use-case.

## Decision

CloudFormation šablona (`cloudformation/honeypot-comparison.yaml`)
zůstává v repu jako **srovnávací/vzdělávací artefakt** — nebyla
integrována jako aktivní součást architektury. Po ověření nasazení
a zdokumentování zjištění byl CloudFormation stack odstraněn
(`aws cloudformation delete-stack`), aby nezdvojoval náklady a
expozici bez odpovídajícího přínosu.

## Zjištění ze srovnání

| Aspekt | Terraform | CloudFormation |
|---|---|---|
| Formát | HCL | YAML/JSON |
| Nejnovější AMI | `data "aws_ami"` — přímý dotaz na EC2 API s filtry | `{{resolve:ssm:...}}` — čte se z veřejného SSM parametru |
| **IAM požadavky navíc** | Jen EC2 permissions stačily | Navíc vyžaduje `cloudformation:*` akce (samostatná API) **a** `ssm:GetParameters` (kvůli AMI resolution přes SSM) — dvě sady oprávnění, které Terraform pro stejný výsledek nepotřeboval |
| Workflow | Dvoufázový: `plan` (explicitní náhled) → `apply` (potvrzení) | `deploy` — jednofázový příkaz, changeset se vytváří a řeší interně |
| State management | Lokální/remote state soubor, který sám spravuješ a musíš chránit (`.gitignore`) | AWS spravuje stav stacku interně, nic lokálně neexistuje |
| Reference na atribut | `resource.name.attribut` | `!GetAtt LogicalId.Attribut` |
| Multi-cloud | Ano | Ne, jen AWS |

**Nejvýznamnější praktický postřeh:** stejná infrastruktura vyžadovala
v CloudFormation o **dvě IAM oprávnění navíc** (CloudFormation service
akce, SSM read), která Terraform vůbec nepotřeboval. To je konkrétní,
měřitelný rozdíl v "hidden dependencies" mezi nástroji, ne jen otázka
syntaxe.

## Alternatives considered

| Alternativa | Proč zamítnuta |
|---|---|
| Nedělat srovnání vůbec, zůstat jen u Terraformu | Ochudilo by to portfolio o praktickou, ne jen teoretickou znalost obou hlavních AWS IaC přístupů |
| Nechat CloudFormation stack běžet trvale vedle Terraformu | Dva souběžné honeypoty nepřidávají žádnou architektonickou hodnotu, jen zdvojují náklady a síťovou expozici bez důvodu |
| Migrovat celý projekt na CloudFormation místo Terraformu | Terraform zůstává lepší volbou pro tento projekt (viz původní zdůvodnění v README) — experiment byl čistě o pochopení rozdílů, ne o změně směru |

## Consequences

**Pozitiva:**
- Reálná, z první ruky získaná zkušenost s oběma hlavními AWS IaC
  nástroji — silnější odpověď u pohovoru než jen "znám Terraform
  teoreticky, o CloudFormation jsem četl"
- Konkrétní, citovatelný příklad rozdílu v IAM požadavcích mezi nástroji

**Trade-offy / rizika:**
- Krátkodobě běžely dva honeypoty současně — mírně zvýšená expozice
  a náklady po dobu experimentu, vyřešeno rychlým úklidem

**Co to vyžaduje do budoucna:**
- Žádné — CloudFormation stack byl odstraněn, šablona zůstává v repu
  jen jako referenční/srovnávací kód, nespravuje žádnou živou
  infrastrukturu

## Related

- ADR-004 — Honeypot design a rozsah nasazení přes Terraform
- ADR-005 — Vlastní VPC pro honeypot místo default VPC
- `cloudformation/honeypot-comparison.yaml` — šablona použitá v experimentu

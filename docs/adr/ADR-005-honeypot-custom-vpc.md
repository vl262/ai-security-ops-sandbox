# ADR-005: Vlastní VPC pro honeypot místo default VPC

**Status:** Accepted
**Datum:** 2026-09-05
**Autor:** Vlad

## Context

Honeypot (ADR-004) byl původně nasazen do **default VPC** Workload
účtu — AWS automaticky vytváří jednu default VPC s výchozím veřejným
subnetem v každém regionu každého účtu, a `aws_instance` v Terraformu
ji použije, pokud `subnet_id`/`vpc_id` není explicitně zadán.

Otázka, jestli síťová vrstva (VPC, subnety) zaslouží explicitní
architektonické rozhodnutí, vyplynula až při zpětném pohledu na
architektonický diagram — service-level abstrakce diagramu síťovou
topologii nezobrazovala, což vedlo k ověření, co běží "pod kapotou".

## Decision

Honeypot byl přesunut do vlastní, izolované VPC:

- **VPC:** `10.42.0.0/24`, DNS support a DNS hostnames povoleny
- **Veřejný subnet:** `10.42.0.0/28`, s `map_public_ip_on_launch = true`
- **Internet Gateway** připojená k VPC
- **Route table** s výchozí trasou `0.0.0.0/0` do Internet Gateway,
  asociovaná s veřejným subnetem

Honeypot instance a její security group byly rekreovány (Terraform
`-/+` replace) do téhle nové sítě — což vedlo i ke změně veřejné IP
adresy (viz README timeline).

Subnet je záměrně "veřejný" (má route do internetu) — to je nutná
podmínka pro funkci honeypotu (viz README: cíl je nechat honeypot
najít internetovými boty), ne bezpečnostní opomenutí.

## Alternatives considered

| Alternativa | Proč zamítnuta |
|---|---|
| Ponechat default VPC | Funkčně by fungovalo stejně, ale default VPC je sdílená napříč čímkoliv dalším, co by v účtu mohlo v budoucnu vzniknout — chybí explicitní izolace a je to méně reprezentativní ukázka VPC designu pro portfolio/certifikační účely |
| Privátní subnet s NAT Gateway pro honeypot | Honeypot musí být přímo dosažitelný z internetu (to je celý smysl) — privátní subnet s NAT by řešil opačný problém (odchozí přístup bez příchozí dosažitelnosti) a navíc by NAT Gateway přidal nezanedbatelné měsíční náklady bez odpovídajícího přínosu |
| Víc subnetů (multi-AZ) pro vyšší dostupnost | Honeypot je záměrně jednoduchý, jednorázový, dočasný zdroj (auto-shutdown za 3 dny) — vysoká dostupnost není relevantní cíl |

## Consequences

**Pozitiva:**
- Honeypot je síťově izolovaný od čehokoliv jiného, co by mohlo
  v budoucnu ve Workload účtu vzniknout
- Explicitní VPC/subnet/IGW/route table kód demonstruje pochopení
  síťové vrstvy, ne jen spoléhání na AWS výchozí nastavení — přímo
  relevantní pro SAP-C02 network design doménu
- Malý, srozumitelný `/24` rozsah drží konfiguraci jednoduchou a
  čitelnou pro portfolio účely

**Trade-offy / rizika:**
- Změna vyžadovala destroy+recreate instance a security group —
  nová veřejná IP adresa, honeypot "začal znovu" z hlediska
  expozice internetu a auto-shutdown časovače
- O jeden vrstvu infrastruktury navíc ke spravování (i když u
  Terraformu je to jen dalších ~50 řádků kódu)

**Co to vyžaduje do budoucna:**
- Aktualizovat architektonický diagram o VPC/subnet vrstvu, pokud
  má odrážet i síťovou topologii, ne jen service-level dataflow
- Při budoucím rozšíření (např. víc honeypot instancí nebo jiné
  Workload zdroje) zvážit, jestli sdílet tuhle VPC, nebo separovat
  dál

## Related

- ADR-004 — Honeypot design a rozsah nasazení přes Terraform
- `terraform/workload_sandbox/network.tf` — implementace

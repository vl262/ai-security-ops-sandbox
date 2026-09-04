# ADR-003: CSPM baseline review — nálezy a jejich vyřešení

**Status:** Accepted — implementováno
**Datum:** 2026-09-04
**Autor:** Vlad

## Context

Původním záměrem bylo použít AWS Well-Architected Tool jako první krok
formálního hodnocení architektury (baseline review). Při přípravě se
ukázalo, že Well-Architected Tool je čistě sebehodnotící dotazník —
neskenuje účet ani negeneruje automatická zjištění.

Automatické, konfigurací řízené hodnocení už mezitím poskytovala
**Security Hub CSPM (Posture management)** — součást Essentials bundle,
který se automaticky aktivoval při onboardingu Security Hub (viz
ADR-002). Rozhodli jsme se proto použít tato reálná CSPM zjištění jako
první praktický "baseline review" místo (nebo před) formálním
Well-Architected dotazníkem.

Filtrováno na `Product name = Security Hub` (vyloučeny GuardDuty sample
findings), pohled z Management accountu (CSPM agreguje napříč
organizací i mimo delegovaného administrátora). Celkem 406 nálezů:
2 Critical, 4 High, 26 Medium, 17 Low, 357 Informational (většina
Informational se týká služeb, které v projektu vůbec nepoužíváme —
CSPM aplikuje kontroly plošně na všechny AWS služby).

## Decision

Zaměřili jsme se na Critical a High nálezy jako první prioritu. Rozhodnutí
u jednotlivých nálezů:

| Nález | Severity | Rozhodnutí | Stav |
|---|---|---|---|
| Hardware MFA should be enabled for the root user | Critical | Root MFA byl nastaven už na začátku projektu; finding pravděpodobně odrážel stav před konfigurací nebo striktně vyžadoval hardware (ne virtuální) MFA klíč | Ověřeno v IAM Dashboard — root MFA aktivní |
| SSM documents should have block public sharing setting enabled | Critical | Opraveno — účet SSM nikdy aktivně nepoužit, ale defaultní stav umožňoval veřejné sdílení. Preventivní guardrail bez vedlejších efektů | ✅ Opraveno |
| CloudTrail should be enabled and configured with at least one multi-Region trail | High | Skutečná mezera — CloudTrail byl součástí původního architektonického návrhu (Fáze 2), ale při implementaci opomenut ve prospěch GuardDuty/Security Hub. Vytvořen `vl-organization-trail`: multi-region, organizational trail (pokrývá Management, Security, Workload), Management events Read+Write, SSE-S3 šifrování (ne KMS — konzistentní s cost-minimalizací zbytku projektu), log file validation a recursive logging zapnuté | ✅ Opraveno |
| VPC default security groups should not allow inbound or outbound traffic | High | Nízké riziko — žádné zdroje v default SG, žádný workload je aktivně nepoužívá | Akceptováno, neřešeno |
| Block public access settings should be enabled for Amazon EBS snapshots | High | Relevantní až s Fází B (honeypot EC2) — preventivní nastavení bez nákladů | Zvážit před Fází B |
| Amazon Inspector Lambda code scanning should be enabled | High | Součást Essentials bundle (ADR-002), vyžaduje doladění konfigurace | Nízká priorita, neřešeno |
| Add MFA for yourself (IAM recommendation, ne přímo CSPM finding) | — | Nekonzistence — root chráněn MFA, ale denní IAM účet (`VL-manager`) ne | ✅ Opraveno |

## Alternatives considered

| Alternativa | Proč zamítnuta |
|---|---|
| Použít jen Well-Architected Tool dotazník, bez CSPM dat | Dotazník je subjektivní sebehodnocení bez ověření proti skutečné konfiguraci — CSPM dává objektivnější, konfigurací podložený výchozí bod |
| Opravit všech 406 nálezů bez priorizace | Naprostá většina (357 Informational) se týká nepoužívaných služeb — investovat čas do jejich "opravy" by nepřineslo žádnou bezpečnostní hodnotu |
| Ignorovat CSPM úplně a spoléhat jen na GuardDuty/Security Hub finding aggregation | CSPM odhaluje konfigurační mezery (chybějící CloudTrail), které GuardDuty jako čistě behaviorální detekční nástroj nikdy nezachytí |

## Consequences

**Pozitiva:**
- Rychlá, konkrétní zjištění bez nutnosti ručně procházet desítky
  Well-Architected otázek pro totéž
- Odhalilo skutečnou mezeru v architektuře (CloudTrail), ne jen
  kosmetické nedostatky
- Vynutilo konzistentní MFA napříč root i běžným IAM přístupem

**Trade-offy / rizika:**
- CSPM nálezy jsou širší než architektura samotná (plošné kontroly
  napříč všemi AWS službami) — vyžaduje aktivní filtrování/priorizaci,
  jinak snadno zahltí signál šumem
- Nenahrazuje formální Well-Architected review napříč všemi 6 pilíři
  (Cost, Reliability, Performance, Sustainability nejsou CSPM
  pokryty vůbec) — zůstává otevřené jako budoucí doplněk

**Co to vyžaduje do budoucna:**
- Před Fází B (honeypot) zvážit EBS snapshot public access block
- Formální Well-Architected Tool review zůstává hodnotný doplněk pro
  pilíře mimo Security (Cost Optimization má už teď silný materiál
  z ADR-002 a README)

## Related

- ADR-002 — Přijetí nerozdělitelného Security Hub Essentials plánu
  (zdroj CSPM capabilities)
- `docs/well-architected/` — místo pro budoucí formální review

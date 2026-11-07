# Andalusian public health sources (SAS / Junta)

Site map and page shapes for "when does X open", "which centre is mine",
vaccination campaigns. Verify the current campaign year every time — the layout
is stable, the content is not.

## Which page answers what

| Question | Page |
|---|---|
| Which centres exist in my district / zona básica | `sspa.juntadeandalucia.es/servicioandaluzdesalud/el-sas/servicios-y-centros/informacion-por-centros/<distrito-id>` — expands to zonas básicas, each listing its centros and consultorios |
| Address, phones, zone, reference hospital of one centre | `…/informacion-por-centros/<centre-id>` (same numeric-id pattern as the distrito page) |
| Campaign groups, cronograma, opening to the general public | `…/ciudadania/vacunas/vacunacion-gripe-y-covid-19` |
| Walk-in (sin cita) points and hours | `…/ciudadania/vacunas/vacunacion-gripe-y-covid-19/puntos-de-vacunacion-sin-cita/<view-id>` — `21291` is the province index, ids such as `21292` render a single point. The bare path with no id 404s, and the index may render its instruction text with no `<select>` at all |
| Campaign instructions (PDF) | Junta "Instrucción SGSPPS-…" documents, linked from Andavac / SAS campaign pages |
| Independent campaign summary | `andavac.es/campanas/gripe/` |
| Press releases naming a centre | `juntadeandalucia.es/organismos/presidenciasanidadyemergencias/…/noticias/detalle/<id>.html` — check the publication date in the body |

## Centro ficha fields to capture

Nombre exacto · dirección postal + núcleo · código postal · teléfonos (two or
three, all of them) · horario L-V · zona básica · distrito · **área hospitalaria
de referencia** · fecha de actualización · email `cs.<centro>.<distrito>.sspa@…`.

Pair each centro with its district page entry: the distrito page is the check
that nothing was missed; the ficha is the source of the details.

## Known traps

- The district page groups several municipalities; a municipality can hold more
  than one centro and more than one núcleo de población.
- Centro fichas carry a "Gripe y COVID-19: vacunación sin cita. Ver horario"
  link on some pages and not others; the link's presence is not a service
  guarantee and its absence is not proof of absence.
- Press round-ups of walk-in hours are published once per campaign and keep
  ranking for the next one. Read the byline date; a list dated in the previous
  campaign describes the previous campaign's groups and hours.
- A walk-in index that shows the heading and "Seleccione cualquier provincia y
  pulse Consultar" but no `<select>` is not populated yet: report "no publicado"
  instead of reusing last campaign's hours. Confirm from the DOM
  (`document.querySelectorAll('select').length === 0`) rather than from a
  screenshot, and allow that the table appears only near the first jornada.
- Junta news items about a named centre can be years old and about a different
  product entirely (e.g. a COVID vaccine brand), yet surface for
  "<centre> vacunación sin cita".

## User-side facts worth freezing once

Municipality, pedanía, centro de salud asignado (exact SAS name), distance to the
other centres in the same zona básica as a sanity check, and the eligibility
attributes that decide the answer (age band, risk conditions, cohabitants).

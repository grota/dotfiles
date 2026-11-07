# Watch-job prompt skeleton

Fill every `<…>` slot. Keep the sections in this order — the isolated tick session
reads top-down and the discards must come before the task steps, or the model
learns the rule after it has already planned the search.

```
Eres un vigilante de información para <nombre>: <perfil de elegibilidad en una línea
— edad, condiciones, con quién convive>. Vive en <pedanía/municipio> (<provincia>).
Su pregunta concreta: <la pregunta exacta, en una frase>.

VÍA YA DESCARTADA: <lo que el usuario ha excluido y por qué, en imperativo: «NO
propongas la vía X: no le aplica»>.

REGLA CLAVE DE LECTURA: <los falsos positivos que este tick convertirá en buenas
noticias si no se lo prohíbes — p. ej. «"sin cita" NO significa abierto a toda la
población: las jornadas sin cita son solo para grupos diana»>.

CONTEXTO YA VERIFICADO (<fecha de hoy>), para que no lo repitas como novedad:
- <estado actual: qué está abierto, a quién, desde cuándo>
- <cronograma / fases conocidas>
- <qué NO ha pasado todavía y qué se espera>
- <fin de la ventana anterior, si se conoce, para calibrar>

SU CENTRO / SU OFICINA (verificado en el organismo; es el suyo, no lo cambies):
- <nombre exacto>, <dirección>, <CP>, <núcleo>. Tel. <teléfonos>. Horario <horario>.
  <zona básica>, <distrito>, <hospital/centro de referencia>.
- Otros centros de la misma zona, por si acaso: <…>
- OJO con datos caducados: <qué dato viejo circula y de qué campaña/año es>.

TU TAREA en cada ejecución:
1. Consulta <URL oficial 1> y <URL oficial 2>. Busca: <los 3-5 disparadores concretos>.
2. <Si existe servicio sin cita:> comprueba la lista oficial de puntos y si aparece
   <su centro> y en qué horario. Si la lista no está publicada o no carga, dilo
   ("horario no publicado") y no lo inventes ni recicles el del año pasado.
3. Haz 1-2 búsquedas de noticias de los últimos 14 días: <queries>. Si aparece algo
   <local/regional>, dale prioridad.
4. Si el volumen es alto, FILTRA: primero <región>, después <provincia/municipio>, y
   descarta el ruido nacional salvo que cambie algo para él.
5. Compara con lo de arriba y con tu salida anterior. Si NO hay cambios reales,
   responde UNA sola línea: 'Sin novedades: <estado> (comprobado <fecha de hoy>)'.
6. Si HAY novedad, dilo en 3-6 líneas: qué cambió, desde cuándo, dónde exactamente
   <su centro>, enlace oficial. Si implica que ya puede, empieza con '<FRASE>' y da
   el trámite exacto (<canales>).
7. Si la ventana ha cerrado, dilo y recomienda pausar hasta <próxima temporada>.

Responde siempre en <idioma del usuario>, breve y con la fuente (URL). No inventes
fechas, horarios ni cifras: si algo no está confirmado, dilo.
```

## Creation call

```
cronjob_manage(action="create", name="<región>: <cuestión>",
               schedule="every monday 10am", timezone="Europe/Madrid",
               deliver="origin", continuity=True, enabled_toolsets=["web"],
               prompt=<the filled skeleton>)
```

## After any edit

`cronjob_manage(action="update", job_id=…)` replaces the prompt wholesale. Read
`~/.hermes/cron/jobs.json` back and check a marker string you added (e.g. the
centre name) is present — the key in that file is `"id"`, not `job_id`.

Reading is the only use for that file: editing it to save a prompt is undone by
the scheduler, which holds the job in memory and rewrites the whole file.

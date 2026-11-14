# ============================================================
# SNAKEFILE PRINCIPAL
# Pipeline de variantes genéticas - JAK3
# ============================================================
# Ponto de entrada do Snakemake. Carrega a configuração,
# define as variáveis globais e inclui os módulos de regras.
#
# Execução:
#   snakemake --dry-run --cores 1 --sdm conda
#
# Recursos computacionais:
#   O parâmetro --cores limita o número total de cores
#   disponibilizados para a execução do workflow.
#
#   Recomenda-se iniciar com --cores 1 ou --cores 2 em
#   computadores com recursos limitados.
# ============================================================

import re

# Configuração geral
configfile: "config/config.yaml"


SAMPLES = config["samples"]


wildcard_constraints:
    sample="|".join(map(re.escape, SAMPLES)),
    read="[12]",


# ------------------------------------------------------------
# Inclusão dos módulos
# ------------------------------------------------------------

include: "rules/reference.smk"

include: "rules/simulation.smk"

include: "rules/quality.smk"

include: "rules/alignment.smk"

include: "rules/metrics.smk"

include: "rules/variant_caller.smk"

include: "rules/annotation.smk"

include: "rules/reports.smk"


rule all:
    input:
        "results/multiqc/multiqc_report.html",
        expand("results/alignment/{sample}.depth.txt", sample=SAMPLES),
        expand("results/variants/{sample}.filtered.vcf.gz", sample=SAMPLES),
        expand("results/variants/{sample}.filtered.vcf.gz.tbi", sample=SAMPLES),
        expand("results/variants/{sample}.vep_summary.html", sample=SAMPLES),
        expand("results/variants/{sample}.annotated.tsv", sample=SAMPLES),

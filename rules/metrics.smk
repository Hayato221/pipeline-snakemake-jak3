# ============================================================================
# PIPELINE DE VARIANTES GENÉTICAS - JAK3
# MÓDULO: METRICS
# GERAÇÃO DAS MÉTRICAS
# ============================================================================
#
# Este módulo calcula métricas por amostra para avaliar
# os resultados do alinhamento, incluindo estatísticas
# de mapeamento e profundidade de leitura.
#
# Ferramentas utilizadas:
# - SAMtools flagstat
# - SAMtools stats
# - SAMtools depth
# ============================================================


# ------------------------------------------------------------
# 1. SAMtools Flagstat
# ------------------------------------------------------------
# Gera um resumo das informações de alinhamento do arquivo BAM.
#
# Apresenta métricas como:
# - Total de registros de alinhamento.
# - Reads mapeadas e não mapeadas.
# - Reads corretamente pareadas.
# - Reads identificadas como duplicatas.


rule samtools_flagstat:
    input:
        bam="results/alignment/{sample}.sorted.markdup.bam",
    output:
        flagstat="results/alignment/{sample}.flagstat.txt",
    log:
        "logs/alignment/{sample}.flagstat.log",
    conda:
        "../envs/alignment.yaml"
    shell:
        "samtools flagstat {input.bam:q} > {output:q} 2> {log:q}"

# ------------------------------------------------------------
# 2. SAMtools Stats
# ------------------------------------------------------------
# Produz um relatório abrangente com estatísticas do arquivo
# BAM, incluindo informações sobre:
# - Quantidade de reads e bases mapeadas.
# - Qualidade de mapeamento (MAPQ).
# - Distribuição do tamanho dos fragmentos (insert size).
# - Comprimento das reads.
# - Distribuição da profundidade de leitura (COV).
# - Estatísticas de GC e mismatches, utilizando a referência.
#
# A opção -r fornece a sequência de referência para o cálculo
# de determinadas métricas, como GC-depth e mismatches por ciclo.
#
# OBS: A opção -d (--remove-dups) não foi utilizada.
# Portanto, reads marcadas como duplicatas permanecem
# incluídas nas estatísticas geradas pelo SAMtools.


rule samtools_stats:
    input:
        bam="results/alignment/{sample}.sorted.markdup.bam",
        ref="reference/chr19.fa",
        fai="reference/chr19.fa.fai",
    output:
        stats="results/alignment/{sample}.stats.txt",
    log:
        "logs/alignment/{sample}.stats.log",
    conda:
        "../envs/alignment.yaml"
    shell:
        "samtools stats -r {input.ref:q} {input.bam:q} > {output:q} 2> {log:q}"

# ------------------------------------------------------------
# 3. SAMtools Depth
# ------------------------------------------------------------
# Calcula a profundidade de leitura (depth) por posição
# dentro da região genômica de interesse.
#
# -a: inclui posições sem cobertura (depth = 0).
# -r: restringe a análise à região definida em config.yaml.
#
# O resultado apresenta o cromossomo, a posição genômica
# e a quantidade de reads que cobrem cada base.
#
# O arquivo gerado permite calcular métricas regionais como
# cobertura média, desvio padrão (SD), coeficiente de variação
# (CV) e cobertura na posição da variante.
#
# OBS: Por padrão, samtools depth exclui reads marcadas
# como duplicatas, além de reads não mapeadas, secundárias
# e reprovadas no controle de qualidade.


rule samtools_depth:
    input:
        bam="results/alignment/{sample}.sorted.markdup.bam",
        bai="results/alignment/{sample}.sorted.markdup.bai",
    output:
        depth="results/alignment/{sample}.depth.txt",
    log:
        "logs/alignment/{sample}.depth.log",
    conda:
        "../envs/alignment.yaml"
    params:
        region=config["target_region"],
    shell:
        "samtools depth -a -r {params.region:q} {input.bam:q} > {output.depth:q} 2> {log:q}"

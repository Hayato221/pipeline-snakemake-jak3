# ============================================================================
# PIPELINE DE VARIANTES GENÉTICAS - JAK3
# MÓDULO: QUALITY
# CONTROLE DE QUALIDADE
# ============================================================================
#
# Este módulo realiza a avaliação da qualidade das reads
# antes e após o processamento com fastp.
#
# Etapas:
# 1. Avaliação da qualidade das reads brutas (FastQC).
# 2. Processamento e filtragem das reads (fastp).
# 3. Avaliação da qualidade das reads processadas (FastQC).
# ============================================================

# ------------------------------------------------------------
# 1. Avaliação da qualidade dos reads brutos (FastQC)
# ------------------------------------------------------------
# Analisa a qualidade dos dados de sequenciamento antes
# do processamento com fastp.
#
# Avalia métricas como:
# - Qualidade das bases ao longo das reads (escore Phred).
# - Distribuição do conteúdo GC.
# - Conteúdo de bases indeterminadas (N).
# - Níveis de duplicação das sequências.
# - Conteúdo de adaptadores.
# - Sequências super-representadas.
#
# Gera relatórios HTML e ZIP para inspeção dos resultados.


rule fastqc_raw:
    input:
        "data/{sample}_{read}.fq",
    output:
        html="results/fastqc_raw/{sample}_{read}_fastqc.html",
        zip="results/fastqc_raw/{sample}_{read}_fastqc.zip",
    log:
        "logs/fastqc_raw/{sample}_{read}.log",
    conda:
        "../envs/qc.yaml"
    threads: 1
    shell:
        "fastqc -t {threads} {input:q} --outdir results/fastqc_raw/ 2> {log:q}"

# ------------------------------------------------------------
# 2. Processamento e filtragem das reads (fastp)
# ------------------------------------------------------------
# Processa os arquivos paired-end (R1 e R2), realizando:
#
# - Adapter Trimming: remoção de sequências de adaptadores.
#
# - Quality Filtering: filtragem de reads com baixa qualidade,
#   considerando os critérios de qualidade padrão do fastp.
#
# - Length Filtering: descarta reads que apresentam comprimento
#   inferior ao mínimo definido em config.yaml (-l).
#
# Gera arquivos FASTQ processados e relatórios HTML e JSON.


rule fastp:
    input:
        r1="data/{sample}_1.fq",
        r2="data/{sample}_2.fq",
    output:
        r1_clean=temp("results/clean/{sample}_1_clean.fq.gz"),
        r2_clean=temp("results/clean/{sample}_2_clean.fq.gz"),
        html="results/clean/{sample}_fastp.html",
        json="results/clean/{sample}_fastp.json",
    log:
        "logs/fastp/{sample}.log",
    conda:
        "../envs/qc.yaml"
    threads: 2
    params:
        min_length=config["fastp"]["min_length"],
    shell:
        """
        fastp \
            -i {input.r1:q} \
            -I {input.r2:q} \
            -o {output.r1_clean:q} \
            -O {output.r2_clean:q} \
            -h {output.html:q} \
            -j {output.json:q} \
            -w {threads} \
            -l {params.min_length} \
            2>{log:q}
        """

# ------------------------------------------------------------
# 3. Avaliação da qualidade dos reads processados (FastQC)
# ------------------------------------------------------------
# Avalia novamente a qualidade das reads após o processamento
# com fastp, permitindo comparar as métricas antes e depois
# da filtragem.
#
# Verifica principalmente:
# - Qualidade das bases ao longo das reads (escore Phred).
# - Distribuição do conteúdo GC.
# - Conteúdo de bases indeterminadas (N).
# - Níveis de duplicação das sequências.
# - Conteúdo residual de adaptadores.
#
# Gera relatórios HTML e ZIP para inspeção dos resultados.


rule fastqc_clean:
    input:
        "results/clean/{sample}_{read}_clean.fq.gz",
    output:
        html="results/fastqc_clean/{sample}_{read}_clean_fastqc.html",
        zip="results/fastqc_clean/{sample}_{read}_clean_fastqc.zip",
    log:
        "logs/fastqc_clean/{sample}_{read}.log",
    conda:
        "../envs/qc.yaml"
    threads: 1
    shell:
        "fastqc -t {threads} {input:q} --outdir results/fastqc_clean/ 2> {log:q}"

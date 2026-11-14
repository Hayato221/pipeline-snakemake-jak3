# ============================================================================
# PIPELINE DE VARIANTES GENÉTICAS - JAK3
# MÓDULO: REPORTS
# RELATÓRIO MULTIQC
# ============================================================================
#
# Este módulo reúne os relatórios e métricas gerados pelas
# diferentes ferramentas utilizadas ao longo do pipeline,
# consolidando essas informações em um único relatório HTML.
#
# São incluídos resultados das seguintes etapas:
#
# 1 - Controle de qualidade das reads antes e após o fastp
#    (FastQC).
# 2 - Métricas de filtragem e trimming das reads (fastp).
# 3 - Métricas da identificação e marcação de duplicatas
#    (GATK MarkDuplicates).
# 4 - Resumo das estatísticas de alinhamento (samtools flagstat).
# 5 - Estatísticas gerais do alinhamento (samtools stats).
# 6 - Resumo das estatísticas de anotação (Ensembl VEP).
#
# O MultiQC identifica e interpreta os arquivos de saída
# reconhecidos, organizando as métricas em tabelas e gráficos
# interativos para facilitar a visualização e comparação
# entre as amostras.
# ============================================================


rule multiqc:
    input:
        fastqc_raw=expand(
            "results/fastqc_raw/{sample}_{read}_fastqc.zip",
            sample=SAMPLES,
            read=["1", "2"],
        ),
        fastp=expand(
            "results/clean/{sample}_fastp.json",
            sample=SAMPLES,
        ),
        fastqc_clean=expand(
            "results/fastqc_clean/{sample}_{read}_clean_fastqc.zip",
            sample=SAMPLES,
            read=["1", "2"],
        ),
        markdup=expand(
            "results/alignment/{sample}.markdup_metrics.txt",
            sample=SAMPLES,
        ),
        flagstat=expand(
            "results/alignment/{sample}.flagstat.txt",
            sample=SAMPLES,
        ),
        stats=expand(
            "results/alignment/{sample}.stats.txt",
            sample=SAMPLES,
        ),
        vep=expand(
            "results/variants/{sample}.vep_summary.html",
            sample=SAMPLES,
        ),
    output:
        "results/multiqc/multiqc_report.html",
    log:
        "logs/multiqc/multiqc.log",
    conda:
        "../envs/qc.yaml"
    shell:
        """
        multiqc {input:q} \
            --outdir results/multiqc/ \
            --filename multiqc_report.html \
            --force \
            &>{log:q}
        """


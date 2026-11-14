# ============================================================================
# PIPELINE DE VARIANTES GENÉTICAS - JAK3
# MÓDULO: ALIGNMENT
# ALINHAMENTO E MARCAÇÃO DE DUPLICATAS
# ============================================================================
#
# Este módulo realiza o alinhamento das reads paired-end,
# previamente processadas pelo fastp, ao cromossomo 19
# da montagem do genoma de referência GRCh38 (hg38).
#
# Após o alinhamento, as reads são ordenadas por coordenada
# genômica e submetidas à marcação de duplicatas com o GATK.
# ============================================================


# ------------------------------------------------------------
# 1. Alinhamento das reads com BWA-MEM
# ------------------------------------------------------------
# Alinha as reads paired-end (R1 e R2) à referência genômica
# utilizando o BWA-MEM.
#
# As informações de Read Group (-R) são adicionadas ao arquivo
# de alinhamento, identificando a amostra, plataforma e biblioteca.
#
# O resultado em formato SAM é enviado via pipe ao SAMtools,
# que realiza a ordenação por coordenadas genômicas e gera
# o arquivo BAM ordenado.
#
# O arquivo BAM ordenado será utilizado na etapa de
# marcação de duplicatas.


rule alignment:
    input:
        r1="results/clean/{sample}_1_clean.fq.gz",
        r2="results/clean/{sample}_2_clean.fq.gz",
        ref="reference/chr19.fa",
        index="reference/chr19.fa.bwt",
    output:
        temp("results/alignment/{sample}.sorted.bam"),
    log:
        "logs/alignment/{sample}.log",
    conda:
        "../envs/alignment.yaml"
    threads: 2
    params:
        rg=r"@RG\tID:{sample}_ART_RG1\tSM:{sample}\tPL:ILLUMINA\tLB:{sample}_ART_LIB1\tPU:{sample}_ART_SIM_RUN1",
    shell:
        """
        bwa mem -R '{params.rg}' -t 1 {input.ref:q} {input.r1:q} {input.r2:q} 2>{log:q} \
            | samtools sort -m 256M -o {output:q} - 2>>{log:q}
        """

# ------------------------------------------------------------
# 2. Marcação de duplicatas com GATK MarkDuplicates
# ------------------------------------------------------------
# Identifica reads duplicadas com base nas coordenadas
# de alinhamento e as marca no arquivo BAM.
#
# Gera um relatório de métricas contendo informações sobre
# as duplicatas identificadas.
#
# A opção CREATE_INDEX true cria o índice (.bai) do BAM
# processado, permitindo consultas por regiões genômicas.
#
# OBS: Os dados foram simulados pelo ART Illumina e não
# reproduzem etapas de PCR ou duplicação óptica.
# Entretanto, reads sintéticas podem apresentar coordenadas
# de alinhamento coincidentes e serem identificadas 
# como duplicatas.
#
# As duplicatas são marcadas, mas não removidas do BAM,
# pois REMOVE_DUPLICATES não foi ativado.


rule mark_duplicates:
    input:
        bam="results/alignment/{sample}.sorted.bam",
    output:
        bam="results/alignment/{sample}.sorted.markdup.bam",
        bai="results/alignment/{sample}.sorted.markdup.bai",
        metrics="results/alignment/{sample}.markdup_metrics.txt",
    log:
        "logs/alignment/{sample}.mark_duplicates.log",
    conda:
        "../envs/gatk.yaml"
    threads: 1
    shell:
        """
        gatk --java-options "-Xmx2g" MarkDuplicates \
            -I {input.bam:q} \
            -O {output.bam:q} \
            -M {output.metrics:q} \
            --CREATE_INDEX true \
            &>{log:q}
        """

# ============================================================================
# PIPELINE DE VARIANTES GENÉTICAS - JAK3
# MÓDULO: REFERENCE
# PREPARAÇÃO DAS REFERÊNCIAS
# ============================================================================
#
# Este módulo prepara os arquivos de referência utilizados
# pelas etapas de alinhamento, chamada e anotação de variantes.
#
# Arquivos gerados:
# - FASTA do cromossomo 19
# - Índices BWA (.amb, .ann, .bwt, .pac, .sa)
# - Índice FASTA (.fai)
# - Dicionário de sequências (.dict)
# - Anotação genômica GTF do Ensembl 116 e seu índice (.tbi)
# ============================================================


# ------------------------------------------------------------
# 1. Download da referência genômica - cromossomo 19 (UCSC)
# ------------------------------------------------------------
# Baixa o FASTA compactado e o descompacta para uso nas
# etapas posteriores do pipeline.


rule download_fasta_chr19:
    output:
        ref="reference/chr19.fa",
    log:
        "logs/reference/download_fasta_chr19.log",
    conda:
        "../envs/variants.yaml"
    params:
        url=config["reference"]["fasta"]["url"],
    shell:
        r"""
        set -euo pipefail

        curl -fL --retry 3 {params.url:q} 2>{log:q} \
            | gzip -dc >{output.ref:q} 2>>{log:q}
        """

# ------------------------------------------------------------
# 2. Indexação da referência para o BWA
# ------------------------------------------------------------
# Gera os cinco arquivos auxiliares necessários para que o
# BWA possa realizar o alinhamento dos reads.


rule bwa_index:
    input:
        "reference/chr19.fa",
    output:
        expand("reference/chr19.fa.{file}", file=["amb", "ann", "bwt", "pac", "sa"]),
    log:
        "logs/reference/bwa_index.log",
    conda:
        "../envs/alignment.yaml"
    shell:
        "bwa index {input:q} &> {log:q}"

# ------------------------------------------------------------
# 3. Indexação da referência para o SAMtools
# ------------------------------------------------------------
# Cria o arquivo .fai, que permite acessar rapidamente
# regiões específicas da sequência FASTA.


rule samtools_faidx:
    input:
        "reference/chr19.fa",
    output:
        "reference/chr19.fa.fai",
    log:
        "logs/reference/samtools_faidx.log",
    conda:
        "../envs/alignment.yaml"
    shell:
        "samtools faidx {input:q} 2> {log:q}"

# ------------------------------------------------------------
# 4. Criação do dicionário de sequências para o GATK
# ------------------------------------------------------------
# Cria o arquivo .dict com informações sobre as sequências
# da referência, utilizado por ferramentas do GATK.


rule create_sequence_dictionary:
    input:
        ref="reference/chr19.fa",
    output:
        dict="reference/chr19.dict",
    log:
        "logs/reference/dict.log",
    conda:
        "../envs/gatk.yaml"
    shell:
        "gatk CreateSequenceDictionary -R {input.ref:q} -O {output.dict:q} &> {log:q}"


# ------------------------------------------------------------
# 5. Download e preparação da anotação genômica (Ensembl 116)
# ------------------------------------------------------------
# Baixa o GTF do Ensembl, mantém somente os registros do
# cromossomo 19, converte o identificador "19" para "chr19"
# para manter compatibilidade com o nome da sequência FASTA.
#
# Depois, ordena os registros por cromossomo e posição,
# compacta em formato BGZF e cria o índice Tabix (.tbi) 
# para permitir consultas por região


rule download_gtf_chr19:
    output:
        gtf="reference/annotation/chr19.GRCh38.116.gtf.gz",
        tbi="reference/annotation/chr19.GRCh38.116.gtf.gz.tbi",
    log:
        "logs/reference/download_gtf_chr19.log",
    conda:
        "../envs/variants.yaml"
    params:
        url=config["reference"]["gtf"]["url"],
    shell:
        r"""
        set -euo pipefail

        curl -fL --retry 3 {params.url:q} 2>{log:q} \
            | gzip -dc 2>>{log:q} \
            | awk 'BEGIN {{ FS=OFS="\t" }} $1=="19" {{ $1="chr19"; print }}' 2>>{log:q} \
            | sort -t $'\t' -k1,1 -k4,4n -k5,5n 2>>{log:q} \
            | bgzip -c >{output.gtf:q} 2>>{log:q}

        tabix -f -p gff {output.gtf:q} 2>>{log:q}
        """

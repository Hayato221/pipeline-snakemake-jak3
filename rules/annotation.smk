# ============================================================================
# PIPELINE DE VARIANTES GENÉTICAS - JAK3
# MÓDULO: ANNOTATION
# ANOTAÇÃO COM ENSEMBL VEP
# ============================================================================
#
# Este módulo prepara as informações dos bancos de dados
# gnomAD e ClinVar, extraindo apenas a região alvo definida
# no config.yaml.
#
# Em seguida, utiliza o Ensembl VEP para realizar a anotação
# genômica das variantes encontradas, adicionando informações
# sobre genes, transcritos, consequências e nomenclatura HGVS.
#
# Também incorpora informações de frequência populacional do
# gnomAD e classificação clínica do ClinVar.
#
# Ao final, gera um VCF anotado, um resumo HTML e uma tabela
# TSV para facilitar a consulta dos resultados.
# ============================================================


# ------------------------------------------------------------
# 1. Extração da região alvo (gnomAD)
# ------------------------------------------------------------
# Utiliza a região alvo definida no config.yaml e o endereço
# do banco de dados do gnomAD.
#
# O BCFtools view seleciona apenas as variantes presentes na
# região de interesse.
#
# A saída é compactada no formato BGZF (-Oz) e indexada com
# BCFtools index, que cria o índice Tabix (.tbi).


rule extract_gnomad_region:
    output:
        vcf="reference/databases/gnomad.region.vcf.gz",
        tbi="reference/databases/gnomad.region.vcf.gz.tbi",
    log:
        "logs/reference/extract_gnomad_region.log",
    conda:
        "../envs/variants.yaml"
    params:
        url=config["databases"]["gnomad"]["url"],
        target_region=config["target_region"],
    shell:
        r"""
        set -euo pipefail

        log_file="$PWD"/{log:q}
        output_vcf="$PWD"/{output.vcf:q}

        (
            cd reference/databases

            bcftools view \
                -r {params.target_region:q} \
                -Oz \
                -o "$output_vcf" \
                {params.url:q} \
                2>"$log_file"

            bcftools index -t "$output_vcf" \
                2>>"$log_file"
        )
        """

# ------------------------------------------------------------
# 2. Extração da região alvo (ClinVar)
# ------------------------------------------------------------
# Utiliza a região alvo definida no config.yaml e o endereço
# do banco de dados do ClinVar.
#
# Como o ClinVar utiliza o nome "19" para identificar o
# cromossomo, enquanto nossa referência utiliza "chr19",
# primeiro extraímos a região utilizando o nome original.
#
# Em seguida, BCFtools annotate realiza a padronização do
# nome do cromossomo, renomeando "19" para "chr19", conforme
# o arquivo de mapeamento clinvar_chr_rename.txt.
#
# Por fim, a saída é compactada em BGZF e indexada com
# BCFtools index, gerando o índice Tabix (.tbi).


rule extract_clinvar_region:
    input:
        chr_rename="resources/clinvar_chr_rename.txt",
    output:
        vcf="reference/databases/clinvar.region.vcf.gz",
        tbi="reference/databases/clinvar.region.vcf.gz.tbi",
    log:
        "logs/reference/extract_clinvar_region.log",
    conda:
        "../envs/variants.yaml"
    params:
        url=config["databases"]["clinvar"]["url"],
        region_nochr=config["target_region"].removeprefix("chr"),
    shell:
        r"""
        set -euo pipefail

        log_file="$PWD"/{log:q}
        output_vcf="$PWD"/{output.vcf:q}
        rename_file="$PWD"/{input.chr_rename:q}

        (
            cd reference/databases

            bcftools view \
                -r {params.region_nochr:q} \
                -Ou \
                {params.url:q} \
                2>"$log_file" \
                | bcftools annotate \
                    --rename-chrs "$rename_file" \
                    -Oz \
                    -o "$output_vcf" \
                    - \
                    2>>"$log_file"

            bcftools index -t "$output_vcf" \
                2>>"$log_file"
        )
        """

# ------------------------------------------------------------
# 3. Anotação genômica (Ensembl VEP)
# ------------------------------------------------------------
# Recebe o VCF filtrado, a sequência de referência, a anotação
# gênica no formato GTF e os bancos de dados ClinVar e gnomAD,
# juntamente com seus respectivos índices.
#
# O Ensembl VEP identifica as consequências previstas das
# variantes sobre genes e transcritos, fornecendo informações
# como gene, consequência, impacto e nomenclatura HGVS.
#
# Através do parâmetro --custom, incorpora informações
# adicionais:
# - ClinVar: classificação clínica, nível de revisão e doença
#   associada à variante.
# - gnomAD: frequência alélica na população (AF).
#
# O VEP também verifica a concordância do alelo de referência
# com o FASTA (--check_ref) e gera informações HGVS.
#
# A saída é um VCF anotado, contendo as consequências no campo
# CSQ, além de um relatório HTML com o resumo da anotação.


rule vep_annotation:
    input:
        vcf="results/variants/{sample}.filtered.vcf.gz",
        tbi="results/variants/{sample}.filtered.vcf.gz.tbi",
        ref="reference/chr19.fa",
        fai="reference/chr19.fa.fai",
        gtf="reference/annotation/chr19.GRCh38.116.gtf.gz",
        gtf_index="reference/annotation/chr19.GRCh38.116.gtf.gz.tbi",
        clinvar="reference/databases/clinvar.region.vcf.gz",
        clinvar_tbi="reference/databases/clinvar.region.vcf.gz.tbi",
        gnomad="reference/databases/gnomad.region.vcf.gz",
        gnomad_tbi="reference/databases/gnomad.region.vcf.gz.tbi",
    output:
        vcf_annotated="results/variants/{sample}.annotated.vcf.gz",
        tbi="results/variants/{sample}.annotated.vcf.gz.tbi",
        stats="results/variants/{sample}.vep_summary.html",
    log:
        "logs/variants/{sample}.vep_annotation.log",
    conda:
        "../envs/vep.yaml"
    params:
        assembly=config["reference"]["genome_assembly"],
    shell:
        """
        vep \
            --input_file {input.vcf:q} \
            --output_file {output.vcf_annotated:q} \
            --stats_file {output.stats:q} \
            --format vcf \
            --vcf \
            --compress_output bgzip \
            --assembly {params.assembly:q} \
            --gtf {input.gtf:q} \
            --fasta {input.ref:q} \
            --check_ref \
            --hgvs \
            --symbol \
            --canonical \
            --biotype \
            --variant_class \
            --flag_pick \
            --custom file={input.clinvar:q},short_name=ClinVar,format=vcf,type=exact,coords=0,fields=CLNSIG%CLNREVSTAT%CLNDN \
            --custom file={input.gnomad:q},short_name=gnomAD_exomes,format=vcf,type=exact,coords=0,fields=AF \
            --force_overwrite \
            &>{log:q}

        tabix -f -p vcf {output.vcf_annotated:q} 2>>{log:q}
        """

# ------------------------------------------------------------
# 4. Anotação genômica em formato TSV (Tabela)
# ------------------------------------------------------------
# Recebe o VCF anotado pelo Ensembl VEP e utiliza o BCFtools
# query para extrair as informações de interesse em formato
# de tabela (TSV).
#
# A tabela reúne informações da variante, métricas de qualidade
# e genótipo da amostra, além das consequências anotadas pelo
# VEP armazenadas no campo CSQ.


rule vep_annotation_tsv:
    input:
        vcf="results/variants/{sample}.annotated.vcf.gz",
    output:
        tsv="results/variants/{sample}.annotated.tsv",
    log:
        "logs/variants/{sample}.vep_annotation_tsv.log",
    conda:
        "../envs/variants.yaml"
    shell:
        """
        printf "CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tQD\tSOR\tFS\tMQ\tGT\tDP\tAD\tGQ\tCSQ\n" >{output.tsv:q}

        bcftools query \
            -f '%CHROM\\t%POS\\t%ID\\t%REF\\t%ALT\\t%QUAL\\t%FILTER\\t%INFO/QD\\t%INFO/SOR\\t%INFO/FS\\t%INFO/MQ\\t[%GT\\t%DP\\t%AD\\t%GQ]\\t%INFO/CSQ\\n' \
            {input.vcf:q} \
            >>{output.tsv:q} 2>>{log:q}
        """


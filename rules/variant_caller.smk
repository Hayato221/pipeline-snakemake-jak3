# ============================================================================
# PIPELINE DE VARIANTES GENÉTICAS - JAK3
# MÓDULO: VARIANT CALLER
# CHAMADA DE VARIANTES
# ============================================================================
#
# Este módulo realiza a chamada, genotipagem, normalização
# e filtragem das variantes identificadas nas amostras.
#
# Ferramentas utilizadas:
# - GATK HaplotypeCaller
# - GATK GenotypeGVCFs
# - BCFtools norm
# - BCFtools index
# - GATK VariantFiltration
# ============================================================


# ------------------------------------------------------------
# 1. GATK HaplotypeCaller
# ------------------------------------------------------------
# Analisa as reads alinhados no BAM e identifica regiões
# com evidências de variação em relação à referência.
#
# Nessas regiões, realiza a remontagem local dos haplótipos
# candidatos e avalia as evidências das reads para estimar
# os genótipos possíveis.
#
# A opção -ERC GVCF gera um arquivo GVCF contendo informações
# de confiança genotípica, utilizado como entrada na etapa
# posterior de genotipagem com GenotypeGVCFs.
#
# A chamada é realizada individualmente para cada amostra
# nessa versão do pipeline.


rule haplotype_caller:
    input:
        bam="results/alignment/{sample}.sorted.markdup.bam",
        bai="results/alignment/{sample}.sorted.markdup.bai",
        ref="reference/chr19.fa",
        fai="reference/chr19.fa.fai",
        dict="reference/chr19.dict",
    output:
        gvcf="results/variants/{sample}.g.vcf.gz",
        tbi="results/variants/{sample}.g.vcf.gz.tbi",
    log:
        "logs/variants/{sample}.haplotype_caller.log",
    conda:
        "../envs/gatk.yaml"
    threads: 2
    params:
        region=config["target_region"],
    shell:
        """
        gatk --java-options "-Xmx2g" HaplotypeCaller \
            --native-pair-hmm-threads {threads} \
            -R {input.ref:q} \
            -I {input.bam:q} \
            -L {params.region:q} \
            -O {output.gvcf:q} \
            -ERC GVCF \
            &>{log:q}
        """


# ------------------------------------------------------------
# 2. GATK GenotypeGVCFs
# ------------------------------------------------------------
# Recebe o GVCF produzido pelo HaplotypeCaller e realiza
# a genotipagem final, gerando um arquivo VCF.
#
# Utiliza as informações de probabilidade genotípica
# presentes no GVCF para determinar os genótipos.
#
# OBS: Esta regra é executada individualmente para cada
# amostra, recebendo um único GVCF por execução.
# Portanto, não é realizada genotipagem conjunta entre
# as amostras WT, HOM e HET nesta versão do pipeline.


rule genotype_gvcfs:
    input:
        ref="reference/chr19.fa",
        fai="reference/chr19.fa.fai",
        dict="reference/chr19.dict",
        gvcf="results/variants/{sample}.g.vcf.gz",
        tbi="results/variants/{sample}.g.vcf.gz.tbi",
    output:
        vcf="results/variants/{sample}.raw.vcf.gz",
        tbi="results/variants/{sample}.raw.vcf.gz.tbi",
    log:
        "logs/variants/{sample}.genotype_gvcfs.log",
    conda:
        "../envs/gatk.yaml"
    threads: 1
    shell:
        """
        gatk GenotypeGVCFs \
            -R {input.ref:q} \
            -V {input.gvcf:q} \
            -O {output.vcf:q} \
            &>{log:q}
        """


# ------------------------------------------------------------
# 3. BCFtools norm - Normalização das variantes
# ------------------------------------------------------------
# Padroniza a representação das variantes utilizando
# a sequência de referência como base de comparação.
#
# Realiza principalmente:
# - Left alignment: deslocamento de indels para a posição
#   mais à esquerda possível.
# - Normalização da representação das variantes.
# - Verificação da correspondência do alelo REF com
#   a sequência de referência fornecida (-f).
#
# A opção -Oz gera o VCF comprimido no formato BGZF.
#
# OBS: A divisão de registros multialélicos não foi ativada,
# pois o objetivo deste projeto é analisar uma variante SNP
# bialélica específica (G>A). A opção -m pode ser utilizada
# em workflows que necessitam separar registros multialélicos.


rule bcftools_norm:
    input:
        vcf="results/variants/{sample}.raw.vcf.gz",
        tbi="results/variants/{sample}.raw.vcf.gz.tbi",
        ref="reference/chr19.fa",
        fai="reference/chr19.fa.fai",
    output:
        norm="results/variants/{sample}.norm.vcf.gz",
    log:
        "logs/variants/{sample}.bcftools_norm.log",
    conda:
        "../envs/variants.yaml"
    shell:
        """
        bcftools norm \
            -f {input.ref:q} \
            -Oz \
            -o {output.norm:q} \
            {input.vcf:q} \
            &>{log:q}
        """


# ------------------------------------------------------------
# 4. BCFtools index - Indexação do VCF normalizado
# ------------------------------------------------------------
# Cria o índice Tabix (.tbi) do VCF comprimido e normalizado.
#
# O índice permite o acesso e a consulta rápida de variantes
# em regiões genômicas específicas, além de permitir o uso
# do arquivo por ferramentas que necessitam dessa indexação.


rule bcftools_index:
    input:
        "results/variants/{sample}.norm.vcf.gz",
    output:
        "results/variants/{sample}.norm.vcf.gz.tbi",
    log:
        "logs/variants/{sample}.bcftools_index.log",
    conda:
        "../envs/variants.yaml"
    shell:
        "bcftools index -t {input:q} 2> {log:q}"


# ------------------------------------------------------------
# 5. GATK VariantFiltration - Filtragem de variantes
# ------------------------------------------------------------
# Aplica critérios de qualidade (hard filters) para identificar
# variantes que não atendem aos limiares estabelecidos.
#
# Critérios utilizados:
# - QUAL < 30.0: qualidade da chamada da variante.
# - QD < 2.0: qualidade da chamada por profundidade.
# - SOR > 3.0: viés de orientação das reads.
# - FS > 60: viés de fita (Fisher Strand).
# - MQ < 40: qualidade média de mapeamento.
#
# Cada critério possui um identificador próprio, registrado
# no campo FILTER do VCF.
#
# As variantes reprovadas são marcadas com seus respectivos
# filtros, mas permanecem no arquivo de saída.
#
# OBS: Os limiares configurados foram estabelecidos para
# a filtragem de SNPs e não devem ser considerados filtros
# validados para indels.
#
# As métricas MQRankSum e ReadPosRankSum não foram utilizadas
# como critérios de filtragem nesta versão.


rule variant_filtration:
    input:
        ref="reference/chr19.fa",
        fai="reference/chr19.fa.fai",
        norm="results/variants/{sample}.norm.vcf.gz",
        tbi="results/variants/{sample}.norm.vcf.gz.tbi",
        dict="reference/chr19.dict",
    output:
        vcf="results/variants/{sample}.filtered.vcf.gz",
        tbi="results/variants/{sample}.filtered.vcf.gz.tbi",
    log:
        "logs/variants/{sample}.variant_filtration.log",
    conda:
        "../envs/gatk.yaml"
    threads: 1
    shell:
        """
        gatk VariantFiltration \
            -R {input.ref:q} \
            -V {input.norm:q} \
            -O {output.vcf:q} \
            --filter-expression "QUAL < 30.0" --filter-name "QUAL30" \
            --filter-expression "QD < 2.0" --filter-name "QD2" \
            --filter-expression "SOR > 3.0" --filter-name "SOR3" \
            --filter-expression "FS > 60" --filter-name "FS60" \
            --filter-expression "MQ < 40" --filter-name "MQ40" \
            &>{log:q}
        """

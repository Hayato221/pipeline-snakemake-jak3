# ============================================================================
# PIPELINE DE VARIANTES GENÉTICAS - JAK3
# MÓDULO: SIMULATION
# SIMULAÇÃO DAS AMOSTRAS
# ============================================================================
#
# Este módulo prepara a referência contendo o alelo alternativo
# e simula reads paired-end para três condições genotípicas:
#
# - WT: homozigoto para o alelo de referência.
# - HOM: homozigoto para o alelo alternativo.
# - HET: heterozigoto, representado pela combinação de reads
#        simulados a partir dos haplótipos de referência e alternativo.
#
# Variante simulada:
# NM_000215.4(JAK3):c.1837C>T (p.Arg613Ter)
# Identificador: rs149316157
# Alteração genômica na referência GRCh38: chr19 G>A.
#
# A simulação utiliza o ART Illumina para gerar reads com
# parâmetros de sequenciamento definidos em config.yaml.
# ============================================================

# ------------------------------------------------------------
# 1. Preparação do VCF da variante
# ------------------------------------------------------------
# Converte o VCF de entrada para o formato comprimido BGZF
# e cria seu índice Tabix (.tbi).
#
# O arquivo indexado será utilizado na construção da
# referência contendo o alelo alternativo.


rule compress_variant_vcf:
    input:
        "resources/jak3_G_A.vcf",
    output:
        vcf="intermediate/jak3_G_A.vcf.gz",
        tbi="intermediate/jak3_G_A.vcf.gz.tbi",
    log:
        "logs/variants/compress_variant_vcf.log",
    conda:
        "../envs/variants.yaml"
    shell:
        """
        bcftools view -Oz {input:q} -o {output.vcf:q} 2>{log:q}
        bcftools index -t {output.vcf:q} 2>>{log:q}
        """

# ------------------------------------------------------------
# 2. Construção da referência com o alelo alternativo
# ------------------------------------------------------------
# Aplica a variante G>A do VCF à sequência de referência
# do cromossomo 19 utilizando bcftools consensus.
#
# O resultado é uma sequência FASTA alternativa, utilizada
# para simular as amostras HOM e HET.


rule make_mutant_reference:
    input:
        ref="reference/chr19.fa",
        fai="reference/chr19.fa.fai",
        vcf="intermediate/jak3_G_A.vcf.gz",
        tbi="intermediate/jak3_G_A.vcf.gz.tbi",
    output:
        ref_mut=temp("intermediate/chr19_jak3_G_A.fa"),
    log:
        "logs/variants/make_mutant_reference.log",
    conda:
        "../envs/variants.yaml"
    shell:
        """
        bcftools consensus \
            -f {input.ref:q} \
            {input.vcf:q} \
            >{output.ref_mut:q} \
            2>{log:q}
        """


# ------------------------------------------------------------
# 3. Simulação da amostra WT (Wild-Type)
# ------------------------------------------------------------
# Simula reads paired-end utilizando a referência original,
# sem a introdução da variante alternativa.
#
# Representa uma amostra homozigota para o alelo de referência.
#
# Os parâmetros de comprimento das reads, cobertura, tamanho
# médio dos fragmentos, desvio padrão e seed são definidos
# em config.yaml.


rule simulate_wt:
    input:
        ref="reference/chr19.fa",
    output:
        r1=temp("data/wt_1.fq"),
        r2=temp("data/wt_2.fq"),
    log:
        "logs/simulation/wt.log",
    conda:
        "../envs/art.yaml"
    params:
        read_length=config["simulation"]["read_length"],
        coverage=config["simulation"]["coverage"]["wt"],
        insert_mean=config["simulation"]["insert_mean"],
        insert_sd=config["simulation"]["insert_sd"],
        seeds=config["simulation"]["seeds"]["wt"],
        prefix="data/wt_",
    shell:
        """
        art_illumina \
            -ss HS25 \
            -i {input.ref:q} \
            -p \
            -l {params.read_length} \
            -f {params.coverage} \
            -m {params.insert_mean} \
            -s {params.insert_sd} \
            -rs {params.seeds} \
            -d wt \
            -o {params.prefix:q} \
            -na \
            2>{log:q}
        """

# ------------------------------------------------------------
# 4. Simulação da amostra HOM (homozigoto alternativo)
# ------------------------------------------------------------
# Simula reads paired-end utilizando a referência modificada
# com o alelo alternativo G>A.
#
# Representa uma amostra homozigota para o alelo alternativo,
# na qual os dois cromossomos apresentam a variante.
#
# Os parâmetros de comprimento das reads, cobertura, tamanho
# médio dos fragmentos, desvio padrão e seed são definidos
# em config.yaml.


rule simulate_hom:
    input:
        ref="intermediate/chr19_jak3_G_A.fa",
    output:
        r1=temp("data/hom_1.fq"),
        r2=temp("data/hom_2.fq"),
    log:
        "logs/simulation/hom.log",
    conda:
        "../envs/art.yaml"
    params:
        read_length=config["simulation"]["read_length"],
        coverage=config["simulation"]["coverage"]["hom"],
        insert_mean=config["simulation"]["insert_mean"],
        insert_sd=config["simulation"]["insert_sd"],
        seeds=config["simulation"]["seeds"]["hom"],
        prefix="data/hom_",
    shell:
        """
        art_illumina \
            -ss HS25 \
            -i {input.ref:q} \
            -p \
            -l {params.read_length} \
            -f {params.coverage} \
            -m {params.insert_mean} \
            -s {params.insert_sd} \
            -rs {params.seeds} \
            -d hom_alt \
            -o {params.prefix:q} \
            -na \
            2>{log:q}
        """

# ------------------------------------------------------------
# 5. Simulação do haplótipo de referência da amostra HET
# ------------------------------------------------------------
# Simula reads a partir da referência original, representando
# o cromossomo que não contém a variante.
#
# Os parâmetros de comprimento das reads, cobertura, tamanho
# médio dos fragmentos, desvio padrão e seed são definidos
# em config.yaml.
#
# A cobertura utilizada corresponde à contribuição desse 
# haplótipo para a cobertura total esperada da amostra HET. 
#
# Nesta simulação, a cobertura-alvo da amostra HET é
# dividida igualmente entre os dois haplótipos:
# metade na referência e metade no alelo alternativo.


rule simulate_het_ref:
    input:
        ref="reference/chr19.fa",
    output:
        r1=temp("intermediate/reads/het_ref_1.fq"),
        r2=temp("intermediate/reads/het_ref_2.fq"),
    log:
        "logs/simulation/het_ref.log",
    conda:
        "../envs/art.yaml"
    params:
        read_length=config["simulation"]["read_length"],
        coverage=config["simulation"]["coverage"]["het"],
        insert_mean=config["simulation"]["insert_mean"],
        insert_sd=config["simulation"]["insert_sd"],
        seeds=config["simulation"]["seeds"]["het_ref"],
        prefix="intermediate/reads/het_ref_",
    shell:
        """
        art_illumina \
            -ss HS25 \
            -i {input.ref:q} \
            -p \
            -l {params.read_length} \
            -f {params.coverage} \
            -m {params.insert_mean} \
            -s {params.insert_sd} \
            -rs {params.seeds} \
            -d het_ref \
            -o {params.prefix:q} \
            -na \
            2>{log:q}
        """

# ------------------------------------------------------------
# 6. Simulação do haplótipo alternativo da amostra HET
# ------------------------------------------------------------
# Simula reads a partir da referência modificada com G>A,
# representando o cromossomo que contém a variante.
# 
# Os parâmetros de comprimento das reads, cobertura, tamanho
# médio dos fragmentos, desvio padrão e seed são definidos
# em config.yaml.
# 
# Utiliza a mesma cobertura configurada para o haplótipo
# de referência, contribuindo igualmente para a cobertura
# total esperada da amostra HET.


rule simulate_het_mut:
    input:
        ref="intermediate/chr19_jak3_G_A.fa",
    output:
        r1=temp("intermediate/reads/het_mut_1.fq"),
        r2=temp("intermediate/reads/het_mut_2.fq"),
    log:
        "logs/simulation/het_mut.log",
    conda:
        "../envs/art.yaml"
    params:
        read_length=config["simulation"]["read_length"],
        coverage=config["simulation"]["coverage"]["het"],
        insert_mean=config["simulation"]["insert_mean"],
        insert_sd=config["simulation"]["insert_sd"],
        seeds=config["simulation"]["seeds"]["het_mut"],
        prefix="intermediate/reads/het_mut_",
    shell:
        """
        art_illumina \
            -ss HS25 \
            -i {input.ref:q} \
            -p \
            -l {params.read_length} \
            -f {params.coverage} \
            -m {params.insert_mean} \
            -s {params.insert_sd} \
            -rs {params.seeds} \
            -d het_mut \
            -o {params.prefix:q} \
            -na \
            2>{log:q}
        """

# ------------------------------------------------------------
# 7. Combinação dos reads dos dois haplótipos da amostra HET
# ------------------------------------------------------------
# Concatena os arquivos FASTQ dos haplótipos de referência
# e alternativo, separadamente para R1 e R2.
#
# O resultado representa uma população de reads proveniente
# dos dois alelos, simulando uma amostra heterozigota.
#
# Como cada haplótipo é simulado com a cobertura definida em
# config.yaml, a cobertura total esperada é aproximadamente
# duas vezes o valor configurado em coverage.het.


rule combine_het_reads:
    input:
        het_ref_1="intermediate/reads/het_ref_1.fq",
        het_ref_2="intermediate/reads/het_ref_2.fq",
        het_mut_1="intermediate/reads/het_mut_1.fq",
        het_mut_2="intermediate/reads/het_mut_2.fq",
    output:
        r1=temp("data/het_1.fq"),
        r2=temp("data/het_2.fq"),
    log:
        "logs/simulation/het.log",
    shell:
        """
        cat {input.het_ref_1:q} {input.het_mut_1:q} >{output.r1:q} 2>{log:q}
        cat {input.het_ref_2:q} {input.het_mut_2:q} >{output.r2:q} 2>>{log:q}
        """


# ============================================================================
# PIPELINE DE VARIANTES GENÉTICAS - JAK3
# EXTRAÇÃO E CÁLCULO DE MÉTRICAS COM AWK
# ============================================================================
#
# Calcula métricas de profundidade a partir dos arquivos gerados pelo SAMtools:
#
# 1. Regional: média, desvio-padrão (DP) e coeficiente de variação (CV).
# 2. Global: profundidade média estimada do cromossomo 19.
# 3. Sítio: profundidade na posição da variante (chr19:17836001).
#
# Os resultados são armazenados em CSVs na pasta docs/data/.
#
# Execução:
# Os comandos devem ser executados dentro da pasta do experimento,
# por exemplo: experiments/independent_seeds/coverage_30x/
#
# Exemplo utilizado: WT, cobertura nominal de 30x.
# Para outras amostras e coberturas, altere as variáveis e os arquivos.
#
# ============================================================================


# ============================================================================
# 1. CRIAÇÃO DOS CABEÇALHOS DOS ARQUIVOS CSV
# ============================================================================
#
# printf: escreve os nomes das colunas nos arquivos CSV.
# >: cria o arquivo ou substitui todo o conteúdo existente.
#
# ATENÇÃO: executar somente uma vez, na criação dos arquivos.
# Não executar novamente depois de inserir os resultados, pois os dados
# anteriores serão apagados.

printf "amostra,cobertura_nominal,total_posicoes,profundidade_media_regional,dp,cv\n" > ../../../docs/data/metricas_regionais.csv

printf "amostra,cobertura_nominal,profundidade_media_global\n" > ../../../docs/data/metricas_globais.csv

printf "amostra,cobertura_nominal,profundidade_sitio\n" > ../../../docs/data/metricas_sitio.csv


# ============================================================================
# 2. MÉTRICAS REGIONAIS: MÉDIA, DESVIO-PADRÃO E COEFICIENTE DE VARIAÇÃO
# ============================================================================

# -v: cria variáveis no AWK e atribui valores antes da leitura do arquivo.
# amostra: identifica o genótipo analisado.
# cobertura: identifica a cobertura nominal da simulação.

awk -v amostra="wt" -v cobertura="30x" '{
    x = $3;

    soma += x;
    soma_quadrados += x * x;
    total_posicoes++;
}
END {
    if (total_posicoes > 0) {
        media = soma / total_posicoes;
        variancia = (soma_quadrados / total_posicoes) - media * media;

        if (variancia < 0) variancia = 0;

        dp = sqrt(variancia);
        cv = (media > 0) ? (dp / media) * 100 : 0;

        printf "%s,%s,%d,%.2f,%.2f,%.2f\n",
               amostra, cobertura, total_posicoes, media, dp, cv;
    } else {
        printf "%s,%s,0,NA,NA,NA\n", amostra, cobertura;
    }
}' wt.depth.txt >> ../../../docs/data/metricas_regionais.csv


# ============================================================================
# 3. MÉTRICA GLOBAL: PROFUNDIDADE MÉDIA DO CROMOSSOMO 19
# ============================================================================

# Calcula o comprimento total da referência FASTA do cromossomo 19.
#
# !/^>/: seleciona as linhas que não começam com ">" (cabeçalhos FASTA).
# length($0): conta o número de caracteres da linha de sequência.
# total +=: acumula o comprimento das linhas.
# END: executa o print depois de terminar a leitura do arquivo.
#
# $(...): Captura o resultado do AWK e armazena na variável tamanho_chr19.

tamanho_chr19=$(awk '
    !/^>/ {
        total += length($0)
    }
    END {
        print total
    }
' ../../../reference/chr19.fa)

# Confere o comprimento da referência.
# Resultado esperado: 58617616 bases.

echo "$tamanho_chr19"


# Calcula a profundidade média global a partir da distribuição COV
# do arquivo gerado pelo SAMtools stats.

# -v: passa o comprimento da referência, a amostra e a cobertura
# do Bash para variáveis utilizadas dentro do AWK.

awk \
    -v tamanho_chr19="$tamanho_chr19" \
    -v amostra="wt" \
    -v cobertura="30x" '
$1 == "COV" {
    soma_profundidade += $3 * $4;
    encontrou_cov = "sim";
}
END {
    if (tamanho_chr19 > 0 && encontrou_cov == "sim") {
        media_global = soma_profundidade / tamanho_chr19;

        printf "%s,%s,%.2f\n",
               amostra, cobertura, media_global;
    } else {
        printf "%s,%s,NA\n", amostra, cobertura;
    }
}' wt.stats.txt >> ../../../docs/data/metricas_globais.csv


# ============================================================================
# 4. MÉTRICA DO SÍTIO: PROFUNDIDADE NA POSIÇÃO DA VARIANTE
# ============================================================================
# -v posicao: informa a coordenada genômica que será procurada.

awk \
    -v amostra="wt" \
    -v cobertura="30x" \
    -v posicao=17836001 '
$1 == "chr19" && $2 == posicao {
    profundidade_sitio = $3;
    encontrou = "sim";
}
END {
    if (encontrou == "sim") {
        printf "%s,%s,%d\n",
               amostra, cobertura, profundidade_sitio;
    } else {
        printf "%s,%s,NA\n", amostra, cobertura;
    }
}' wt.depth.txt >> ../../../docs/data/metricas_sitio.csv

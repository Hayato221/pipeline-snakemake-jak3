# ============================================================================
# PIPELINE DE VARIANTES GENÉTICAS - JAK3
# GRÁFICO DO DESVIO-PADRÃO DA PROFUNDIDADE REGIONAL
# ============================================================================
#
# Gera um gráfico de barras agrupadas comparando o desvio-padrão (DP)
# da profundidade regional das amostras WT, HOM e HET nas coberturas
# nominais de 5x, 10x e 30x.
#
# O desvio-padrão representa a dispersão das profundidades em relação
# à média regional, considerando as 601 posições da janela
# chr19:17835701-17836301, que abrange a região-alvo do gene JAK3.
#
# Bibliotecas utilizadas:
# Pandas: leitura e manipulação dos dados.
# Seaborn: criação do gráfico.
# Matplotlib: personalização e salvamento da figura.
#
# Execução (a partir da raiz do projeto):
# python scripts/python/profundidade_desvio_padrao.py
#
# ============================================================================


# Importa as bibliotecas necessárias

import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt


# Lê o arquivo CSV contendo as métricas regionais

dados = pd.read_csv("docs/data/metricas_regionais.csv")


# Padroniza os nomes das amostras, transformando-os em maiúsculas

dados["amostra"] = dados["amostra"].str.upper()


# Define as cores utilizadas para representar cada amostra
# e a cor de fundo do gráfico

CORES = {"WT": "#2a78d6", "HOM": "#1baf7a", "HET": "#eb6834"}
FUNDO = "#fdfdfc"


# Configura o estilo visual e as cores de fundo da figura

sns.set_theme(
    style="white",
    rc={
        "figure.facecolor": FUNDO,
        "axes.facecolor": FUNDO,
        "savefig.facecolor": FUNDO
    },
)


# Define o tamanho da figura (largura e altura em polegadas)

plt.figure(figsize=(9, 5.8))


# Cria o gráfico de barras agrupadas
# Define os dados dos eixos X e Y
# Separa as amostras por cores
# Estabelece a ordem das coberturas e das amostras
# Ajusta a saturação das cores e o espaçamento entre as barras
# Desativa as barras de incerteza automáticas

ax = sns.barplot(
    data=dados,
    x="cobertura_nominal",
    y="dp",
    hue="amostra",
    order=["5x", "10x", "30x"],
    hue_order=["WT", "HOM", "HET"],
    palette=CORES,
    saturation=1,
    gap=0.1,
    errorbar=None
)


# Define o título da legenda

ax.get_legend().set_title("Amostra")


# Adiciona os valores acima das barras
# Formata os números com duas casas decimais
# Substitui o ponto decimal por vírgula e acrescenta "x"
# para representar a unidade de profundidade.

for barras in ax.containers:
    ax.bar_label(
        barras,
        fmt=lambda v: f"{v:.2f}".replace(".", ",") + "x",
        padding=4
    )


# Define o título do gráfico e os nomes dos eixos

plt.title("Desvio-padrão da profundidade na janela do gene JAK3")
plt.xlabel("Cobertura nominal (solicitada ao ART)")
plt.ylabel("Desvio-padrão da profundidade (x)")


# Ajusta a margem vertical, adicionando espaço acima das barras.
# Remove as bordas superior e direita dos eixos.
# Ajusta os espaçamentos da figura para evitar sobreposições.

ax.margins(y=0.1)
sns.despine()
plt.tight_layout()


# Salva a figura no diretório indicado, com resolução de 300 DPI.

plt.savefig(
    "docs/figures/profundidade_desvio_padrao.png",
    dpi=300
)


# Exibe o gráfico na tela

plt.show()

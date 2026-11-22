# ============================================================================
# PIPELINE DE VARIANTES GENÉTICAS - JAK3
# GRÁFICO DA PROFUNDIDADE MÉDIA GLOBAL
# ============================================================================
#
# Gera um gráfico de barras agrupadas comparando a profundidade média global
# das amostras WT, HOM e HET nas coberturas nominais de 5x, 10x e 30x.
#
# A profundidade média global corresponde à profundidade média estimada
# ao longo das 58.617.616 bases do cromossomo 19 (GRCh38).
#
# O cálculo é realizado a partir da distribuição de profundidade (COV)
# apresentada nos arquivos gerados pelo SAMtools stats.
#
# Bibliotecas utilizadas:
# Pandas: leitura e manipulação dos dados.
# Seaborn: criação do gráfico.
# Matplotlib: personalização e salvamento da figura.
#
# Execução (a partir da raiz do projeto):
# python scripts/python/profundidade_media_global.py
#
# ============================================================================


# Importa as bibliotecas necessárias

import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt


# Lê o arquivo CSV contendo as métricas globais

dados = pd.read_csv("docs/data/metricas_globais.csv")


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
    y="profundidade_media_global",
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
# para representar a profundidade.

for barras in ax.containers:
    ax.bar_label(
        barras,
        fmt=lambda v: f"{v:.2f}".replace(".", ",") + "x",
        padding=4
    )


# Define o título do gráfico e os nomes dos eixos

plt.title("Profundidade média global do cromossomo 19")
plt.xlabel("Cobertura nominal (solicitada ao ART)")
plt.ylabel("Profundidade média global (x)")


# Ajusta a margem vertical, adicionando espaço acima das barras.
# Remove as bordas superior e direita dos eixos.
# Ajusta os espaçamentos da figura para evitar sobreposições.

ax.margins(y=0.1)
sns.despine()
plt.tight_layout()


# Salva a figura no diretório indicado, com resolução de 300 DPI.

plt.savefig(
    "docs/figures/profundidade_media_global.png",
    dpi=300
)


# Exibe o gráfico na tela

plt.show()

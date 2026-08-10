# Weighty

App Android pessoal para registrar cargas de musculação e acompanhar a
evolução de treino a treino. Sem gamificação, sem metas, sem rede social:
o único indicador é quanto você levantou em relação à última vez.

O nome visível é **Weighty**. O `applicationId` continua `br.com.luan.treino`,
e isso é de propósito: ele é a identidade do app para o Android, e trocá-lo
faria o aparelho tratar a próxima versão como um app diferente — instalação
nova, histórico de treinos zerado. `test/brand_test.dart` tranca as duas
coisas para a diferença continuar sendo uma decisão e não um descuido.

## Como funciona

Você monta treinos (Upper 1, Lower 1, ...), escolhe os exercícios e as séries
de cada um. Ao iniciar uma sessão, cada campo de carga já vem com o valor da
última vez em cinza — concluir a série sem digitar nada repete aquele valor.
Assim que a série é concluída, aparece o delta (`+2,5 kg vs 67,5 × 9`).

### Tipos de série

Toda série é uma lista ordenada de segmentos `(carga, reps)`:

| Tipo | Segmentos | Exemplo |
|---|---|---|
| Normal | 1 | 70 kg × 9 |
| Aquecimento | 1 | 40 kg × 12 (fora dos indicadores) |
| Drop set | N, carga decrescente | 60×8 → 45×6 → 30×5 |
| Cluster set | N, mesma carga | 80 × (3+3+3) |

Acrescentar rest-pause ou myo-reps é um valor novo no enum `SetType`, sem
migração de banco.

### Indicadores

- **Carga máxima** — maior carga entre os segmentos.
- **Volume** — soma de carga × reps.
- **1RM estimado** — Epley (`carga × (1 + reps/30)`), só para séries de até
  12 repetições; acima disso o app omite em vez de mostrar número duvidoso.
- **Veredito** — compara a carga máxima; empate desempata por repetições.
- **Recorde de carga** — a carga máxima do dia superou **tudo** o que já foi
  registrado antes daquela sessão. Estrear um exercício não conta: sem marca
  anterior não há o que bater.

## Rodando

```bash
flutter pub get
dart run build_runner build   # gera database.g.dart
flutter test
flutter build apk --release --split-per-abi
```

O APK de instalação é `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

### Assinatura

O release usa `android/key.properties` se o arquivo existir, e cai na chave de
debug se não existir. Para assinar com a sua chave:

```bash
keytool -genkey -v -keystore ~/treino-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias treino
```

Depois crie `android/key.properties` (já está no `.gitignore`):

```properties
storeFile=/Users/<voce>/treino-upload.jks
storePassword=<senha>
keyAlias=treino
keyPassword=<senha>
```

Trocar de chave depois de instalar exige desinstalar o app antes de atualizar —
o Android recusa updates com assinatura diferente.

## Design

O app não usa os widgets padrão do Material. `lib/app/design/` define um sistema
próprio e as telas importam só `design/design.dart`.

- **Cor de ação: bronze** (`#E0A64B` no escuro, `#9A6E14` no claro). Verde e
  vermelho ficam reservados **só para progressão** — se o botão fosse verde,
  "evoluiu" perderia força como sinal.
- **Grupos musculares têm cor própria**, usada em pontos de 7 px e barras de
  2 px. Nenhum tom cai na faixa do bronze (para não parecer ação) nem na do
  verde (para não sugerir progresso).
- **Tipografia Inter**, embarcada em `assets/fonts` (400/500/600). Numerais
  tabulares em toda carga e repetição: sem isso a coluna "dança" quando 9 vira
  10 no meio da série.
- **Escala compacta**: corpo de 15 px, alvos de toque de 44 px. A hierarquia vem
  de peso e cor, não de tamanho.
- **Uma ação cheia por app.** `AppButton` é pílula (raio = altura ÷ 2) e por
  padrão tem a largura do conteúdo. `expand: true` aparece **uma vez** em todo o
  código, em "Concluir série": é a única ação tocada com a mão suada, entre
  séries, sem olhar a tela. Retângulo cheio de largura total é a silhueta do
  botão do Material, e dar essa força a "Salvar" e "Criar treino" fazia tudo
  parecer igualmente urgente.
- **Telas de detalhe não têm barra de navegação.** Em vez dela, `AppBackLink`
  põe "‹ Histórico" em bronze acima do título grande — sem hairline, sem fundo,
  fixo. A barra de 48 px com título pequeno era a última forma de Material do
  app e repetia informação que o título grande já dava; um link nomeado ainda
  diz *para onde* volta. O nome vem na query (`?de=Histórico`) porque a mesma
  tela é aberta de lugares diferentes.
- **Barra de abas própria** (54 px) no lugar do `NavigationBar` do Material, que
  tem 80 px e pílula animada atrás do ícone. As telas raiz não têm barra de
  navegação: o título grande mora no conteúdo.
- **Ícones Lucide**, não os do Material — o conjunto de ícones é um dos maiores
  denunciadores de "app Android padrão".
- **Rolagem elástica** e sem o brilho de overscroll, pelo `AppScrollBehavior`.
- **Componentes próprios** no lugar dos padrões: `AppToast` (SnackBar),
  `showAppDialog` (AlertDialog, no formato de alerta do iOS), `InsetGroup` +
  `AppRow` (lista agrupada), `AppSegmented`, `AppChip`, `NumberCell`.

Os rótulos de coluna vivem em `ColumnHeader`, nunca dentro das células. Foi o
que corrigiu o desalinhamento entre carga e repetições: um rótulo embaixo do
campo faz a coluna crescer e, numa `Row` centralizada, empurra o input para
cima.

### Marca

O símbolo é uma anilha vista de frente: aro largo e claro (o arco de evolução,
com uma abertura), corpo apagado e furo pequeno. A proporção entre as três
partes é o que separa o desenho de um gráfico de rosca qualquer — anel fino com
buraco grande lê como rosca; disco cheio com furo pequeno lê como anilha.

Ele é **desenhado em código**, em `lib/app/design/brand.dart`. Os PNGs do
launcher saem do mesmo painter:

```bash
flutter test tool/gen_icon.dart
```

Rodar de novo é seguro e sobrescreve os mipmaps. É isso que garante que o ícone
no launcher e a marca dentro do app nunca divirjam. Passando
`PREVIEW_OUT=/caminho.png` sai também uma folha de contato com o desenho nos
tamanhos em que ele aparece de verdade.

### Abertura

`app/splash.dart` desenha a abertura **por cima** do app já montado, pelo
`builder` do MaterialApp — não é rota nem espera. O app é construído embaixo e já
está pronto quando a camada sai; o único custo é o toque ficar retido por 750 ms.
Ela segue o tema escolhido e leva a autoria e os direitos, que aparecem também no
rodapé dos Ajustes pelo mesmo `AppCredit`.

Duas coisas que só apareceram no aparelho:

- Como filho não posicionado de um `Stack`, a camada recebia restrição solta e
  saía com a largura do texto, encostada à esquerda, com o app aparecendo atrás.
  Precisa de `Positioned.fill`.
- Sem um `Material` acima, o Flutter desenha todo texto com o sublinhado amarelo
  duplo de "faltou Material". A abertura é a única tela que não passa pelo
  `AppScaffold`, e o card exportado é rasterizado isolado — os dois precisam
  trazer o próprio `Material`. `test/splash_test.dart` e
  `test/share_card_test.dart` travam isso.

O quadro que o **Android** pinta antes de o Flutter existir usa
`@color/splash_background`, que tem variante em `values-night` e é travado contra
a paleta do Dart por `test/brand_test.dart`. Esse quadro segue o modo escuro do
**sistema**, não a preferência do app: no Android 12+ o tema da abertura é
resolvido a partir do manifesto antes de qualquer código nosso rodar, então não
há como ele ler uma preferência interna.

### Imagem do treino

`features/share` gera um card 4:5 (1080 × 1350) com nome do treino, séries,
volume, a rosca de grupos musculares, os recordes de carga, a série mais pesada
e quantos exercícios evoluíram. Não há sistema de compartilhamento: o botão
rasteriza o card e grava na galeria, no álbum `Weighty`.

O card segue o tema do app. Consequência aceita: o mesmo treino gera imagens
diferentes no claro e no escuro. A tela não tem barra nem rodapé — o card ocupa
a largura toda e a ação é uma pílula pequena flutuando; 4:5 em largura cheia
cobre uns 55% da altura de um celular alto, e esse é o teto sem trocar a
proporção.

A rosca usa **ponta reta** com fresta de 1,6°, não ponta arredondada. Para
manter a proporção honesta com ponta redonda é preciso descontar meio traço de
cada lado do arco — em traço de 16 px num raio de 62 isso come ~15° por lado, e
uma fatia de 9% (32°) não tem o que dar. O resultado eram proporções
visivelmente erradas e fatias pequenas viradas em pastilhas soltas.

O card tem tamanho fixo, então conteúdo demais estoura em silêncio numa build
release. `test/share_card_test.dart` cobre os casos extremos (lista de recordes
cheia com sobra, doze grupos musculares, nomes longos, treino de uma série só) e
falha se qualquer um deles passar de 400 × 500. Com `SHARE_CARD_OUT=/prefixo`
ele também grava cada caso em PNG para conferência a olho.

## Estrutura

```
lib/
  app/        tema, rotas, providers, preferências, formatação
  data/
    db/       tabelas Drift, seed do catálogo, banco
    repos/    exercícios, treinos, sessões, evolução
    backup/   exportar/importar JSON
  domain/
    models/   enums e modelos puros
    metrics/  volume, carga máxima, 1RM, comparações
  features/   routines, exercises, session, history, share, settings
```

Os dados ficam só no aparelho (SQLite). O backup em JSON, nos ajustes, é a
única forma de sobreviver à troca de celular.

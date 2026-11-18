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

Trocar um exercício de lugar não custa recomeçar: o menu `⋯` do card tem
**Substituir exercício**, que mantém as séries já configuradas. Isso vale porque
as séries planejadas penduram no vínculo entre treino e exercício, não no
exercício em si — e porque a sessão copia o exercício para si mesma quando
começa, então o histórico antigo continua no exercício antigo.

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
próprio e as telas importam só `design/design.dart`. A referência visual é o
iOS 26 (Liquid Glass): barras e controles de vidro flutuando sobre o conteúdo,
cartões sem borda de canto contínuo, tipografia do sistema.

- **Cor de ação: bronze** (`#F5B24A` no escuro, `#A36800` no claro — o
  `#A86B00` do estudo dava 4,4:1 sobre branco). Verde e vermelho ficam
  reservados **só para progressão** — se o botão fosse verde, "evoluiu" perderia
  força como sinal.
- **Cinzas de sistema da Apple**, com fundo preto puro no escuro (`#F2F2F7` no
  claro) e cartão `#1C1C1E`. É o contraste entre os dois que separa o cartão,
  sem linha nenhuma em volta.
- **Grupos musculares têm cor própria**, usada em pontos de 7 px e barras de
  2 px. Nenhum tom cai na faixa do bronze (para não parecer ação) nem na do
  verde (para não sugerir progresso).
- **Tipografia Inter**, embarcada em `assets/fonts` (400 a 700, release 4.1).
  Numerais tabulares em toda carga e repetição: sem isso a coluna "dança" quando
  9 vira 10 no meio da série.
- **Escala do iOS**: corpo de 17, título grande de 34 em negrito, títulos de
  seção de 22 em caixa normal ("Treinos", "Por exercício"). A escala compacta
  anterior (corpo 15, título 28) deixava a hierarquia só na cor. A maiúscula
  pequena com tracking ficou só nos cabeçalhos de coluna.
- **Cantos contínuos.** Toda superfície usa superelipse (`AppShapes`), não arco
  de círculo: cartão de 26, folha e alerta de 32. É a curva sem "quina" onde o
  arco encontra a reta que faz um canto grande parecer Apple.
- **Uma ação cheia por app.** `AppButton` é pílula (raio = altura ÷ 2) e por
  padrão tem a largura do conteúdo. `expand: true` aparece **uma vez** em todo o
  código, em "Concluir série": é a única ação tocada com a mão suada, entre
  séries, sem olhar a tela. Retângulo cheio de largura total é a silhueta do
  botão do Material, e dar essa força a "Salvar" e "Criar treino" fazia tudo
  parecer igualmente urgente.
- **O título grande rola com a lista.** As telas montam o conteúdo em slivers
  pelo `AppScaffold`; o título grande é o primeiro deles e, quando sai de vista,
  reaparece pequeno e centralizado no topo. O topo não tem barra nem linha: é uma
  faixa fixa de botões de vidro sobre um degradê que dissolve o conteúdo, a
  borda de rolagem do iOS 26.
- **O voltar é um círculo de vidro**, como no iOS 26. O nome de destino
  ("Voltar para Histórico") continua indo para o leitor de tela; vem na query
  (`?de=Histórico`) porque a mesma tela é aberta de lugares diferentes.
- **Transição da rota Cupertino**: a tela entra inteira pela direita, a de baixo
  recua com paralaxe, e arrastar da borda volta acompanhando o dedo.
- **Barra de abas em cápsula de vidro**, flutuando 8 px acima da base, com a aba
  ativa numa pílula que desliza com mola. A casca usa `extendBody`: as listas
  passam por baixo dela, e é isso que deixa o vidro aparecer. O
  `NavigationBar` do Material (80 px, pílula atrás do ícone) nunca entrou.
- **Ícones Lucide**, não os do Material — o conjunto de ícones é um dos maiores
  denunciadores de "app Android padrão".
- **Rolagem elástica** e sem o brilho de overscroll, pelo `AppScrollBehavior`.
- **Componentes próprios** no lugar dos padrões: `AppToast` (SnackBar),
  `showAppDialog` (AlertDialog, no formato de alerta do iOS 26), `showAppMenu`
  (menu suspenso), `showAppSheet` (folha), `InsetGroup` + `AppRow` (lista
  agrupada), `AppSegmented`, `AppChip`, `NumberCell`.
- **Tudo encolhe ao toque**, com mola (`PressScale`): botões, chips, cartões
  tocáveis, abas e círculos de vidro. Linhas de lista só realçam, como no iOS.
- **O aviso é uma cápsula de vidro**, não uma barra: `AppToast` abraça o texto,
  centrado acima da barra de abas. Toque ou arrasto para baixo dispensam na
  hora. Quem tem barra embaixo informa o espaço a reservar pelo `ToastInset`
  (`AppTabBar.reservedHeight`); sem isso o toast nascia atrás da barra de abas,
  porque ele mora no Overlay da raiz e não enxerga a tela.
- **Alerta, folha e menu.** O alerta é vidro denso com botões em cápsula lado a
  lado: o preferido em bronze cheio, o destrutivo vermelho sobre o próprio tom —
  vermelho cheio fica de fora, porque no app ele quer dizer "regrediu". A folha
  flutua solta das bordas; a escolha de exercício abre como folha do iOS
  (`CupertinoSheetRoute`), com o editor encolhido atrás e arrasto para fechar.
  Tocar fora fecha qualquer um dos três — e só passou a fechar quando o fundo
  desfocado deixou de engolir o toque (`test/dialog_test.dart`).
- **Todo texto fora de uma tela precisa de um `Material` acima.** Sem ele o
  Flutter desenha o sublinhado amarelo duplo de "faltou Material" — inclusive em
  build release, no aparelho. Já apareceu na abertura e no toast; hoje o
  diálogo, a folha, o toast e o card arrastado do editor têm o seu, e há teste
  de regressão para os dois últimos.

### Vidro

`GlassSurface` desenha o vidro com o que o Flutter oferece: desfoque saturado
do que está atrás, preenchimento translúcido, borda de 1 px que pega luz no
topo e se apaga embaixo, reflexo e sombra. Não há refração — a lente na borda
do vidro da Apple —, e isso é aceito: em tamanho de celular, é a combinação
acima que carrega a leitura de vidro.

- **A saturação importa.** Sem ela o desfoque vira vidro fosco cinza; com ela o
  conteúdo colorido acende através da superfície.
- **Um filtro só, num `BackdropGroup`.** Todos os vidros usam o mesmo filtro e
  ficam sob um grupo na raiz (`main.dart`), então dividem uma passada de
  desfoque em vez de cada um refazer a sua.
- **A sombra é pintada só do lado de fora da forma.** Uma `BoxShadow` comum fica
  embaixo da superfície inteira e, como o vidro é translúcido, aparecia através
  dele como uma meia-lua escura na base de cada círculo.

Vidro é para o que flutua (barra de abas, botões do topo, menu, folha, alerta,
aviso). Cartões e listas, que fazem parte do conteúdo, são superfícies opacas.

### Conferir telas

```bash
PREVIEW_OUT=/caminho flutter test tool/preview_screens.dart
```

Renderiza as telas reais, com os dados de exemplo de `tool/demo_data.dart`, em
PNG nos dois temas — inclusive com a lista rolada sob o vidro, o menu, a folha,
o alerta e o gráfico com o dedo pousado. `PREVIEW_SCALE=3` sai na densidade do
aparelho.

Os rótulos de coluna vivem em `ColumnHeader`, nunca dentro das células. Foi o
que corrigiu o desalinhamento entre carga e repetições: um rótulo embaixo do
campo faz a coluna crescer e, numa `Row` centralizada, empurra o input para
cima.

### Editor de treino

Cada série é um **chip**, não uma linha. Um exercício de 4×10 virava quatro
linhas quase idênticas repetindo a palavra "Normal" — a maior massa visual da
tela e a de menor informação. Em chip, o treino inteiro cabe numa tela e "4×10"
se lê de relance. A cor carrega o tipo: aquecimento só com contorno (não conta
para indicador nenhum), drop e cluster tingidos, normais em superfície de campo.

As ações por exercício moram todas no `⋯` — substituir, duplicar a última série,
remover. Antes eram um X no cabeçalho mais dois botões de texto no rodapé de
**cada** card: com seis exercícios, doze botões na tela. Remover agora confirma,
como já fazia excluir treino. O `⋯` abre um menu de vidro que nasce do próprio
botão; a folha que subia da base levava o olho para longe do que foi tocado.

Reordenar é por **toque longo** no card, sem pegador visível, e o card arrastado
só cresce 3% — o `proxyDecorator` padrão do `ReorderableListView` embrulha o item
num Material com elevação, que é exatamente a sombra que denuncia Android padrão.

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
release. Por isso ele tem tipografia própria, congelada na escala compacta: a
escala do app cresceu para a tela, onde há rolagem, e aqui não há. `test/share_card_test.dart` cobre os casos extremos (lista de recordes
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

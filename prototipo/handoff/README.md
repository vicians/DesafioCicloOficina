# Handoff: Tião Oficina Mecânica — App Completo

## Visão Geral
Sistema completo para oficina mecânica com dois produtos distintos que compartilham o mesmo design system:

1. **App do Cliente** (`Tião Oficina Mecânica.html`) — acompanhamento de serviços, aprovação de orçamento, histórico e notificações
2. **Sistema Interno** (`Tião — Sistema Interno.html`) — login, dashboard do mecânico e painel do gerente (estoque + relatórios)

---

## Sobre os arquivos de design
Os arquivos `.html` neste pacote são **protótipos de referência criados em HTML/React**. Eles demonstram aparência, comportamento e fluxo — mas **não devem ser copiados diretamente para produção**.

A tarefa do desenvolvedor é **recriar esses designs em Flutter/Dart**, respeitando os tokens, componentes e interações documentados abaixo.

## Fidelidade
**Alta fidelidade (hifi).** Cores, tipografia, espaçamentos, sombras e interações estão todos definidos com valores finais. O desenvolvedor deve recriar pixel a pixel usando os tokens abaixo.

---

## Design Tokens

### Paleta de Cores
```dart
// Primárias
const Color navyDark    = Color(0xFF1C2F4A); // Header, gradiente, avatar
const Color navyMid     = Color(0xFF2A4268); // Gradiente secundário
const Color orange      = Color(0xFFF97316); // CTAs, status ativo, nav ativa

// Superfícies
const Color bgPage      = Color(0xFFF4F5F7); // Fundo das telas
const Color cardWhite   = Color(0xFFFFFFFF); // Cards

// Texto
const Color textPrimary   = Color(0xFF111827);
const Color textSecondary = Color(0xFF6B7280);
const Color textMuted     = Color(0xFF9CA3AF);

// Semânticas
const Color green         = Color(0xFF16A34A);
const Color greenBg       = Color(0xFFDCFCE7);
const Color blue          = Color(0xFF2563EB);
const Color blueBg        = Color(0xFFDBEAFE);
const Color yellow        = Color(0xFFD97706);
const Color yellowBg      = Color(0xFFFEF3C7);
const Color red           = Color(0xFFDC2626);
const Color redBg         = Color(0xFFFEE2E2);
const Color purple        = Color(0xFF7C3AED);
const Color purpleBg      = Color(0xFFEDE9FE);

// Bordas
const Color borderColor   = Color(0xFFE5E7EB);
const Color dividerColor  = Color(0xFFF3F4F6);
```

### Tipografia
```dart
// Fonte: DM Sans (Google Fonts)
// flutter pub add google_fonts

const String fontFamily = 'DM Sans';

// Escala
// Títulos de tela:    18–20px, weight 700
// Títulos de card:    14–15px, weight 600–700
// Corpo principal:    13px,    weight 400–500
// Labels/subtítulos:  11–12px, weight 400–600
// Micro (badges):     10–11px, weight 600
```

### Espaçamento e Grid
```dart
// Padding de tela:        16px horizontal, 14–20px vertical
// Gap entre cards:        8–10px
// Padding interno card:   14–16px
// Border radius card:     16px
// Border radius botão:    12px
// Border radius badge:    20px (pill)
// Border radius input:    12px
// Border radius avatar:   50% (circular)
```

### Sombras
```dart
// Card padrão:
BoxShadow(color: Color(0x12000000), blurRadius: 3, offset: Offset(0, 1))

// Card hover/active:
BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 4))

// Botão primário (laranja):
BoxShadow(color: Color(0x44F97316), blurRadius: 14, offset: Offset(0, 4))
```

---

## Status do Serviço — Mapeamento de Cores

| Status       | Label               | Cor texto  | Background | Dot        |
|--------------|---------------------|------------|------------|------------|
| aguardando   | Aguardando          | `#9CA3AF`  | `#F3F4F6`  | `#9CA3AF`  |
| orcamento    | Aprovar orçamento   | `#D97706`  | `#FEF3C7`  | `#D97706`  |
| andamento    | Em andamento        | `#2563EB`  | `#DBEAFE`  | `#2563EB`  |
| revisao      | Em revisão          | `#7C3AED`  | `#EDE9FE`  | `#7C3AED`  |
| concluido    | Concluído           | `#16A34A`  | `#DCFCE7`  | `#16A34A`  |
| cancelado    | Cancelado           | `#DC2626`  | `#FEE2E2`  | `#DC2626`  |

---

## Produto 1 — App do Cliente

### Estrutura de Navegação
Bottom navigation bar com 4 abas:
- **Início** (Home) — tela padrão ao abrir
- **Orçamento** — aprovação de orçamento pendente
- **Histórico** — lista de serviços anteriores
- **Alertas** — notificações

### Tela: Home
**Layout:** ScrollView vertical. Header fixo com gradiente `navyDark → navyMid`, padding `20px 20px 28px`.

**Header:**
- Saudação: "Olá, {nome} 👋" — 12px, opacity 0.55
- Título "Tião Oficina" — 18–20px, weight 700, branco
- Avatar circular 42px (iniciais do usuário) — canto direito

**Card de Status Ativo** (dentro do header, fundo `rgba(255,255,255,0.10)`, borda `rgba(255,255,255,0.14)`, radius 16):
- Indicador pulsante laranja (dot 10px + animação ping)
- Label "EM ANDAMENTO" — 11px, laranja, uppercase, letter-spacing 0.5
- Título do serviço — 15px, weight 600, branco
- Subtítulo carro+placa — 12px, branco 50%
- Barra de progresso — 6px, laranja, cantos arredondados
- Linha inferior: "X% concluído" | "Até {previsão}"

**Conteúdo (padding 16px):**
- Botão primário full-width "Ver detalhes do serviço"
- Card do mecânico: avatar + nome + badge "Online" verde
- Card informativo azul (próxima etapa)
- Seção "Serviços anteriores" com 2 cards de histórico

### Tela: Detalhes do Serviço
**Acessada via:** botão na Home. Sem bottom nav (tela de detalhe).

**Header:** igual ao padrão + botão voltar (chevron esquerdo) + StatusBadge.

**Tabs:** "Acompanhamento" | "Orçamento" — linha indicadora laranja embaixo da ativa.

**Tab Timeline:**
- Lista vertical com linha conectora
- Cada step: círculo 28px (verde=concluído, laranja=ativo, cinza=pendente)
- Step ativo tem `box-shadow: 0 0 0 5px rgba(F97316, 0.17)`
- Linha conectora: 2px, verde se concluído, cinza se não
- Conteúdo: título (weight 600/700) + descrição 12px + timestamp

**Tab Orçamento:**
- Card com lista de itens separados por divider
- Card escuro `navyDark` com total e badge "Aprovado"

### Tela: Aprovação de Orçamento
**Fluxo:** Banner amarelo de alerta → lista de itens → total em card escuro → botões.

**Botão Aprovar:** primário laranja full-width, com loading spinner ao tocar.
**Estado aprovado:** animação scaleIn de círculo verde + mensagem de confirmação.
**Botão Recusar:** outline laranja, ao tocar revela card vermelho com telefone de contato.

### Tela: Histórico
Duas seções com label uppercase cinza:
1. "EM ANDAMENTO" — card com ProgressBar
2. "CONCLUÍDOS" — lista de cards com ícone check verde + data + valor

### Tela: Notificações
Lista de itens. Não lidos: fundo `cardWhite` + dot laranja canto direito.
Ao tocar: marca como lido (sem dot, fundo `rgba(255,255,255,0.45)`).

Tipos de ícone por categoria:
- `progress` → wrench, fundo azul
- `budget` → money, fundo amarelo
- `checkin` → car, fundo roxo
- `done` → check, fundo verde

### Bottom Navigation Bar
- Fundo `rgba(255,255,255,0.95)` + blur 16px
- Padding bottom: 22px (safe area)
- Aba ativa: ícone + label laranjas + linha 2.5px laranja no topo
- Badge vermelho de contagem sobre "Alertas"
- Badge amarelo "1" sobre "Orçamento" quando há pendência

---

## Produto 2 — Sistema Interno (Funcionário + Gerente)

### Tela: Login
**Layout:** ScrollView. Header com gradiente + ícone de chave inglesa centralizado.

**Toggle de modo:** "Senha" | "Código OTP" — segmented control sobre fundo `bgPage`.

**Modo Senha:**
- Input e-mail/telefone
- Input senha (obscureText)
- Banner de erro vermelho com ícone alert (animação shake)
- Botão "Entrar" primário

**Modo OTP:**
- Input e-mail para envio
- Botão "Enviar código por SMS"
- Após envio: 6 inputs numéricos 42×50px, radius 10px
- Auto-avança ao preencher cada dígito, auto-login ao completar 6

**Lógica de role:** e-mail contendo "gerente" → perfil gerente; outros → funcionário.

### Header padrão das telas internas
Gradiente `navyDark → navyMid`, padding `14px 18px`.
Título 18px weight 700 + subtítulo 12px opacity 0.5.

### Tela: Dashboard (Funcionário)
**KPI Row** (dentro do header, 3 colunas):
- Ativos / Aguardando / Hoje — fundo `rgba(255,255,255,0.08)`, valor 20px weight 700 branco

**Banner de alerta** (amarelo) quando há orçamento pendente — toque navega para detalhe.

**Lista de atendimentos ativos:** cards com cliente, carro, StatusBadge, ProgressBar.

**Botão de logout:** ícone `↪` 32×32px, `rgba(255,255,255,0.10)`, canto direito do header.
- Ao tocar: bottom sheet de confirmação com overlay `rgba(0,0,0,0.5)` — `position: absolute` dentro do container do app (não `fixed`)
- "Confirmar saída" (botão primário) + "Cancelar" (outline)

### Tela: Lista de Atendimentos
- Barra de busca no header (fundo `rgba(255,255,255,0.12)`, texto branco)
- Filter chips horizontais (scroll): Todos / Andamento / Orçamento / Aguardando / Concluído
- Chip ativo: fundo `navyDark`, texto branco, borda `navyDark`
- Cards com: nome + ID + carro/placa + StatusBadge + serviço + avatar mecânico + valor

### Tela: Detalhe do Atendimento
3 tabs: **Mensagens** | **Timeline** | **Dados**

**Tab Mensagens (chat):**
- Mensagens do cliente: bolha branca, radius `14 14 14 4`, alinhada à esquerda
- Mensagens do funcionário: bolha `navyDark`, radius `14 14 4 14`, alinhada à direita
- Mensagens de sistema: chip centralizado, fundo `dividerColor`
- Input + botão enviar laranja 40×40px
- Auto-scroll para última mensagem

**Tab Timeline:** igual ao app do cliente.

**Tab Dados:** lista de rows "Label | Valor" em cards separados.

**Ações rápidas no header:**
- "Atualizar status" — fundo `rgba(255,255,255,0.12)`, abre bottom sheet com lista de status
- "Orçamento" — fundo laranja

### Tela: Estoque (somente Gerente)
- Banner vermelho quando itens abaixo do mínimo
- Cards com: ícone tag (vermelho se baixo, verde se ok) + nome + categoria + quantidade + unidade
- ProgressBar: `qty / (min×2) × 100%`, cor vermelha se `qty ≤ min`
- Linha inferior: "Mínimo: X unid." + "R$ preço/unid."
- Botão "Adicionar" laranja no header

### Tela: Relatórios (somente Gerente)
- Card escuro com faturamento total + badge de crescimento `+X%`
- Dois KpiCards lado a lado: Serviços realizados + Ticket médio
- Card "Status dos serviços": lista com ProgressBar por categoria
- Card "Serviços mais realizados": ranking numerado com receita + contagem

### Bottom Navigation — Sistema Interno

**Funcionário (3 abas):** Dashboard | Serviços | Mensagens

**Gerente (4 abas):** Dashboard | Serviços | Estoque | Relatórios

---

## Interações e Animações

| Elemento            | Animação                                      | Duração  |
|---------------------|-----------------------------------------------|----------|
| Troca de tela       | Fade + translateY de 8px → 0                  | 200ms    |
| Bottom sheet        | slideUp (translateY 16px → 0)                 | 220ms    |
| Estado aprovado     | scaleIn (scale 0.75→1) com spring             | 400ms    |
| Dot pulsante        | ping (scale 1→2.8, opacity 0.8→0), loop       | 2200ms   |
| Botão ao pressionar | scale 0.97                                    | 120ms    |
| Card ao hover       | translateY -1px + sombra maior                | 150ms    |
| ProgressBar         | width transition cubic-bezier(.4,0,.2,1)      | 1000ms   |
| Input com erro      | shake (translateX ±5px)                       | 300ms    |
| Loading spinner     | rotate 360°, linear                           | 700ms    |

---

## Componentes Reutilizáveis

### StatusBadge
Pill com dot colorido + label. Inline flex, padding `3px 9px`, radius 20px.

### ProgressBar
Height 6px, radius 99px, gradiente `color → color×0.73`.

### Card
Fundo branco, radius 16px, padding 14px, sombra suave. Hover eleva 1px.

### Btn (Button)
- **Primário:** fundo laranja, texto branco, sombra laranja, radius 12px
- **Outline:** borda 1.5px laranja, texto laranja, fundo transparente
- **Danger:** fundo `redBg`, texto vermelho, borda `red×0.27`
- **Ghost:** sem borda, texto cinza
- Padding: `13px 18px` (normal) | `8px 14px` (small)
- Estado disabled: opacity 0.6

### Input
Borda 1.5px: cinza padrão → `navyDark` no focus → vermelho no erro.
Padding: `13px` (sem ícone) | `13px 13px 13px 40px` (com ícone).

### Avatar
Círculo com gradiente `navyDark → navyMid`, iniciais brancas.

---

## Arquivos neste pacote

| Arquivo                             | Conteúdo                              |
|-------------------------------------|---------------------------------------|
| `Tião Oficina Mecânica.html`        | App do cliente — 5 telas interativas  |
| `Tião — Sistema Interno.html`       | Login + Funcionário + Gerente         |
| `README.md`                         | Este documento                        |

---

## Como usar este handoff

1. Abra os arquivos `.html` no browser para ver o design interativo em funcionamento
2. Use este README como especificação técnica para implementar em Flutter
3. Instale a fonte via `google_fonts`: `GoogleFonts.dmSans(...)`
4. Implemente os tokens de cor como `ThemeData` ou arquivo de constantes
5. Em caso de dúvida visual, o protótipo HTML é a fonte da verdade

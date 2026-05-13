# Tião Oficina — Protótipo Flutter

Protótipo de alta fidelidade do app **Tião Oficina Mecânica**, implementado em Flutter a partir do handoff de design.

## Produtos incluídos

| Produto | Telas |
|---|---|
| **App do Cliente** | Home, Detalhes do serviço, Aprovação de orçamento, Histórico, Notificações |
| **Sistema Interno** | Login (senha + OTP), Dashboard, Lista de serviços, Chat, Estoque, Relatórios |

## Como rodar

### 1. Pré-requisitos
Instale o Flutter SDK: https://docs.flutter.dev/get-started/install

### 2. Instalar dependências
```bash
cd prototipo
flutter pub get
```

### 3. Rodar
```bash
# No browser (mais rápido, sem configuração extra)
flutter run -d chrome

# No emulador Android (requer Android Studio com emulador criado)
flutter run

# No Windows desktop (requer Visual Studio com workload C++)
flutter run -d windows
```

## Login do Sistema Interno
- Senha: `1234` (qualquer e-mail)
- E-mail contendo "gerente" → perfil gerente (Estoque + Relatórios)
- Qualquer outro e-mail → perfil funcionário

## Arquivos de design
A pasta `handoff/` contém os protótipos HTML originais — abra no browser como referência visual.

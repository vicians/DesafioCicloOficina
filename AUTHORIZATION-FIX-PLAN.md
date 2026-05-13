# Plano de Fix: Autorização de Cliente para Orçamentos

## Resumo Executivo

**Status Atual:** Branch `developer` tem segurança implementada, mas bloqueia clientes (role 2) de acessar seus próprios orçamentos. Branch `fix/tela-agendamentos` (HEAD) funciona removendo TODA segurança.

**Problema Raiz:** Endpoint GET `/orcamentos` está configurado para `authorizeRole(['1', '3'])` (funcionário/gerente), excluindo clientes (role 2).

**Solução:** Implementar autorização granular que permite clientes ler APENAS seus próprios orçamentos, mantendo segurança.

---

## Diagnóstico Detalhado

### 1. Diferenças Entre Branches

#### Branch `developer` (INSEGURO PARA CLIENTES)
**Backend - orcamentoRoutes.ts:**
```typescript
orcamentoRouter.get('/', authMiddleware, authorizeRole(['1', '3']), OrcamentoController.index);
```
- Autenticação: ✅ REQUERIDA
- Autorização: ✅ RESTRITA a roles 1 e 3
- **Problema:** Role 2 (cliente) recebe 403 Forbidden

**Frontend - client_flow_api_repository.dart:**
```dart
final orcResp = await ApiHelper.get('$baseUrl/orcamentos');
```
- Headers JWT: ✅ ENVIADOS via ApiHelper
- **Problema:** Servidor rejeita porque role 2 não tem permissão

#### Branch `fix/tela-agendamentos` (INSEGURO GLOBALMENTE)
**Backend - orcamentoRoutes.ts:**
```typescript
orcamentoRouter.get('/', OrcamentoController.index);
```
- Autenticação: ❌ NÃO REQUERIDA
- Autorização: ❌ NENHUMA
- **Resultado:** Qualquer pessoa (autenticada ou não) pode ler TODOS os orçamentos

**Frontend - client_flow_api_repository.dart:**
```dart
final orcResp = await http.get(Uri.parse('$baseUrl/orcamentos'));
```
- Headers JWT: ❌ NÃO ENVIADOS
- Funciona porque endpoint está público

---

## Raiz do Problema

| Camada | Problema | Impacto |
|--------|----------|--------|
| **Backend (Routes)** | Restrição ['1', '3'] exclui role 2 | Clientes recebem 403 |
| **Backend (Controller)** | `findAll()` retorna todos os orçamentos | Sem filtragem por cliente |
| **Frontend (Headers)** | ApiHelper não é usado em HEAD | Sem autenticação JWT |
| **Frontend (Lógica)** | Filtra por `clientId` manualmente no Dart | Depende do backend retornar todos |

---

## Solução Proposta

### Opção 1: Autorização Baseada em Dados (RECOMENDADA)

**Conceito:** Modificar o `OrcamentoController.index()` para filtrar automaticamente orçamentos por cliente quando role = 2.

#### Passo 1: Modificar Backend - orcamentoController.ts

```typescript
static async index(req: Request, res: Response) {
  try {
    // Se cliente (role 2), filtrar apenas seus orçamentos
    if (req.user?.role === '2') {
      const orcamentos = await OrcamentoModel.findByClienteId(req.user.id);
      return res.json(orcamentos);
    }
    
    // Se funcionário/gerente (roles 1 e 3), retornar todos
    const orcamentos = await OrcamentoModel.findAll();
    return res.json(orcamentos);
  } catch (error) {
    return res.status(500).json({ error: 'Erro ao buscar orçamentos' });
  }
}
```

#### Passo 2: Modificar Backend - orcamentoRoutes.ts

```typescript
// Permitir QUALQUER role autenticado, mas controller filtra dados
orcamentoRouter.get('/', authMiddleware, OrcamentoController.index);

// Manter proteção em operações sensíveis
orcamentoRouter.post('/', authMiddleware, authorizeRole(['1', '3']), OrcamentoController.store);
orcamentoRouter.patch('/:id', authMiddleware, authorizeRole(['1', '3']), OrcamentoController.update);
orcamentoRouter.delete('/:id', authMiddleware, authorizeRole(['1']), OrcamentoController.delete);
```

#### Passo 3: Restaurar Frontend - client_flow_api_repository.dart

**Já usa `ApiHelper.get()` em developer - sem mudanças necessárias!**

```dart
// Isso já funciona porque ApiHelper adiciona Authorization header
final orcResp = await ApiHelper.get('$baseUrl/orcamentos');
```

---

### Opção 2: Endpoint Separado para Clientes

**Conceito:** Criar endpoint específico para clientes buscar seus orçamentos.

#### Backend - orcamentoRoutes.ts
```typescript
// Endpoint geral (funcionários/gerentes)
orcamentoRouter.get('/', authMiddleware, authorizeRole(['1', '3']), OrcamentoController.index);

// Endpoint específico para clientes
orcamentoRouter.get('/meus-orcamentos', authMiddleware, authorizeRole(['2']), OrcamentoController.getClienteOrcamentos);
```

#### Backend - orcamentoController.ts
```typescript
static async getClienteOrcamentos(req: Request, res: Response) {
  const orcamentos = await OrcamentoModel.findByClienteId(req.user.id);
  return res.json(orcamentos);
}
```

#### Frontend - client_flow_api_repository.dart
```dart
final orcResp = await ApiHelper.get('$baseUrl/orcamentos/meus-orcamentos');
```

---

## Implementação Recomendada (Opção 1)

### Motivos:
1. ✅ Menos mudanças no código
2. ✅ Filtragem automática no backend (segura por padrão)
3. ✅ Frontend não muda (já usa ApiHelper)
4. ✅ Escalável para outros recursos
5. ✅ Mantém separação clara entre operações

### Arquivos a Modificar:

#### 1. `backend/src/controllers/orcamentoController.ts`
- Modificar método `index()` para filtrar por cliente se role = 2
- Garantir que `OrcamentoModel.findByClienteId()` existe (ou criar)

#### 2. `backend/src/routes/orcamentoRoutes.ts`
- Remover `authorizeRole(['1', '3'])` de GET `/orcamentos`
- Manter autenticação com `authMiddleware`
- Manter restrição em POST/PATCH/DELETE

#### 3. `prototipo/lib/features/cliente/data/client_flow_api_repository.dart`
- Verificar se já usa `ApiHelper.get()` (já deveria estar usando)
- Se não, substituir chamadas diretas por `ApiHelper.get()`

---

## Verificação de Segurança

### Antes (developer - QUEBRADO):
```
Cliente (role 2) → GET /orcamentos → authMiddleware ✅ → authorizeRole(['1','3']) ❌ BLOCKED
```

### Depois (fix/authorization):
```
Cliente (role 2) → GET /orcamentos → authMiddleware ✅ → Controller filtra por cliente ID ✅ → Retorna APENAS seus orçamentos ✅

Funcionário (role 1) → GET /orcamentos → authMiddleware ✅ → Controller retorna TODOS ✅

Admin (role 3) → GET /orcamentos → authMiddleware ✅ → Controller retorna TODOS ✅
```

---

## Fluxo Completo Pós-Fix

### Cenário: Funcionário modifica orçamento, cliente aprova

1. **Funcionário** (role 1) modifica orçamento → PATCH `/orcamentos/{id}` → Status: ENVIADO
2. **Backend** envia notificação push para cliente
3. **Cliente** abre app, chama `fetchCurrentService()` → GET `/orcamentos` com JWT
4. **Backend** vê role 2, filtra por cliente ID, retorna apenas seus orçamentos
5. **Frontend** encontra status ENVIADO, mostra `BudgetApprovalScreen` ✅
6. **Cliente** aprova/rejeita → PATCH `/orcamentos/{id}/aprovar` ou `/rejeitar`

---

## Checklist de Implementação

### Preparação
- [ ] Criar branch `fix/authorization` a partir de `developer`
- [ ] Verificar que `OrcamentoModel` tem método `findByClienteId(clienteId)`

### Backend
- [ ] Modificar `orcamentoController.ts` - método `index()`
- [ ] Modificar `orcamentoRoutes.ts` - remover `authorizeRole` de GET
- [ ] Testar com Postman/Insomnia:
  - [ ] GET `/orcamentos` sem token → 401
  - [ ] GET `/orcamentos` com cliente token → apenas seus orçamentos
  - [ ] GET `/orcamentos` com funcionário token → todos orçamentos
  - [ ] POST `/orcamentos` com cliente token → 403

### Frontend (se necessário)
- [ ] Verificar que `client_flow_api_repository.dart` usa `ApiHelper.get()`
- [ ] Testar fluxo completo no Flutter:
  - [ ] Login como cliente
  - [ ] Modificar agendamento como funcionário
  - [ ] Verificar notificação push
  - [ ] Abrir app cliente → deve mostrar BudgetApprovalScreen

### Database
- [ ] Confirmar que `OrcamentoModel.findByClienteId()` retorna resultados corretos
- [ ] Testar com múltiplos clientes para garantir isolamento

---

## Notas de Segurança

⚠️ **CRÍTICO:** Após implementar, verificar:

1. **Isolation:** Cliente com `id=1` NÃO pode acessar orçamentos de cliente `id=2`
   ```typescript
   // ERRADO (vulnerável):
   if (req.user?.role === '2') {
     const orcamentos = await OrcamentoModel.findByClienteId(req.query.clienteId); // ❌ Pode forjar ID
   }
   
   // CORRETO (seguro):
   if (req.user?.role === '2') {
     const orcamentos = await OrcamentoModel.findByClienteId(req.user.id); // ✅ Usa ID do token
   }
   ```

2. **Operações Protegidas:** POST/PATCH/DELETE devem continuar restritos a roles 1 e 3

3. **Dados Sensíveis:** Verificar se há campos em orçamento que não devem ser vistos por clientes

---

## Próximos Passos

1. Criar branch `fix/authorization` a partir de `developer`
2. Implementar Opção 1
3. Testar endpoint GET com diferentes roles
4. Merge em `developer`
5. Considerar aplicar mesmo padrão a:
   - GET `/agendamentos`
   - GET `/execucoes`
   - GET `/notificacoes`

---

**Data de Criação:** 13/05/2026  
**Status:** Pronto para Implementação  
**Prioridade:** 🔴 ALTA (Bloqueia fluxo de cliente)

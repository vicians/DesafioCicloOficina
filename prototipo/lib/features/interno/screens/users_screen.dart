import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../services/user_service.dart';
import '../data/models/user_item.dart';

class UsersScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const UsersScreen({super.key, this.onOpenDrawer});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<UserItem> _users = [];
  bool _isLoading = true;
  int? _activeFilter; // null = todos, 1 = Gerente, 3 = Mecânico, 2 = Cliente

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final users = await UserService.getUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  List<UserItem> get _filteredUsers {
    if (_activeFilter == null) return _users;
    return _users.where((u) => u.tipoId == _activeFilter).toList();
  }

  void _openEdit(UserItem user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditUserSheet(
        user: user,
        onSave: (updated, _) => _handleSave(updated),
      ),
    );
  }

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditUserSheet(
        user: null,
        onSave: (newUser, pwd) => _handleAdd(newUser, pwd),
      ),
    );
  }

  Future<void> _handleSave(UserItem updated) async {
    final ok = await UserService.updateUser(
      id: updated.id,
      tipoId: updated.tipoId,
      nome: updated.nome,
      telefone: updated.telefone,
      email: updated.email,
    );
    if (!mounted) return;
    if (ok) {
      await _fetchUsers();
      _showActionSnackbar(ok: true, msgSuccess: 'Usuário salvo', msgError: '');
    } else {
      _showActionSnackbar(ok: false, msgSuccess: '', msgError: 'Erro ao salvar usuário');
    }
  }

  Future<void> _handleAdd(UserItem newUser, String? pwd) async {
    final ok = await UserService.createUser(
      tipoId: newUser.tipoId,
      cpfCnpj: newUser.cpfCnpj,
      nome: newUser.nome,
      telefone: newUser.telefone,
      email: newUser.email,
      senha: pwd ?? '',
    );
    if (!mounted) return;
    if (ok) {
      await _fetchUsers();
      _showActionSnackbar(ok: true, msgSuccess: 'Usuário criado com sucesso', msgError: '');
    } else {
      _showActionSnackbar(ok: false, msgSuccess: '', msgError: 'Erro ao criar usuário');
    }
  }

  void _showActionSnackbar({required bool ok, required String msgSuccess, required String msgError}) {
    final msg = ok ? msgSuccess : msgError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: ok ? green : red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    return Column(
      children: [
        _buildHeader(),
        _buildCategoryFilter(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(orange)))
              : filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _UserCard(
                        user: filtered[i],
                        onEdit: () => _openEdit(filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navyMid],
        ),
      ),
      child: Row(
        children: [
          if (widget.onOpenDrawer != null) ...[
            Semantics(
              label: 'Abrir menu',
              button: true,
              child: GestureDetector(
                onTap: widget.onOpenDrawer,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_rounded, size: 19, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usuários',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_users.length} ${_users.length == 1 ? 'cadastrado' : 'cadastrados'}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: orange,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [orangeButtonShadow],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Adicionar',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _FilterChip(
            label: 'Todos',
            isActive: _activeFilter == null,
            onTap: () => setState(() => _activeFilter = null),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _FilterChip(
              label: 'Clientes',
              isActive: _activeFilter == 2,
              onTap: () => setState(() => _activeFilter = 2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _FilterChip(
              label: 'Mecânicos',
              isActive: _activeFilter == 3,
              onTap: () => setState(() => _activeFilter = 3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _FilterChip(
              label: 'Gerentes',
              isActive: _activeFilter == 1,
              onTap: () => setState(() => _activeFilter = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded, size: 48, color: textMuted),
          const SizedBox(height: 12),
          Text(
            'Nenhum usuário encontrado',
            style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? navyDark : cardWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? navyDark : borderColor),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : textSecondary,
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserItem user;
  final VoidCallback onEdit;

  const _UserCard({
    required this.user,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isClient = user.tipoId == 2;
    final isMechanic = user.tipoId == 3;
    
    final iconColor = isClient ? blue : (isMechanic ? orange : green);
    final bgColor = isClient ? blueBg : (isMechanic ? orangeLight : greenBg);
    final iconData = isClient ? Icons.person_rounded : (isMechanic ? Icons.build_rounded : Icons.admin_panel_settings_rounded);

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [cardShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nome,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.profileName} • ${user.telefone}',
                    style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
                  ),
                  if (user.email.isNotEmpty)
                    Text(
                      user.email,
                      style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_rounded, size: 18, color: textMuted),
          ],
        ),
      ),
    );
  }
}

class _EditUserSheet extends StatefulWidget {
  final UserItem? user;
  final void Function(UserItem, String?) onSave;

  const _EditUserSheet({this.user, required this.onSave});

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _docCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _pwdCtrl;
  int _selectedType = 2; // 2 = Cliente (default)

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u?.nome ?? '');
    _docCtrl = TextEditingController(text: u?.cpfCnpj ?? '');
    _phoneCtrl = TextEditingController(text: u?.telefone ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _pwdCtrl = TextEditingController();
    if (u != null) {
      _selectedType = u.tipoId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _docCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final result = UserItem(
      id: widget.user?.id ?? 'LOCAL_${DateTime.now().millisecondsSinceEpoch}',
      tipoId: _selectedType,
      cpfCnpj: _docCtrl.text.trim(),
      nome: _nameCtrl.text.trim(),
      telefone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      ativo: true,
    );

    Navigator.pop(context);
    widget.onSave(result, widget.user == null ? _pwdCtrl.text : null);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Editar Usuário' : 'Novo Usuário',
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perfil de Acesso',
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: bgPage,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedType,
                            isExpanded: true,
                            dropdownColor: cardWhite,
                            style: GoogleFonts.dmSans(fontSize: 14, color: textPrimary),
                            items: const [
                              DropdownMenuItem(value: 2, child: Text('Cliente')),
                              DropdownMenuItem(value: 3, child: Text('Mecânico')),
                              DropdownMenuItem(value: 1, child: Text('Gerente / Administrador')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedType = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _nameCtrl,
                        label: 'Nome completo',
                        hint: 'Ex: João da Silva',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              controller: _docCtrl,
                              label: 'CPF/CNPJ',
                              hint: 'Apenas números',
                              keyboardType: TextInputType.number,
                              validator: (v) => (!isEdit && (v == null || v.trim().isEmpty)) ? 'Obrigatório' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              controller: _phoneCtrl,
                              label: 'Telefone',
                              hint: '(00) 00000-0000',
                              keyboardType: TextInputType.phone,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _emailCtrl,
                        label: 'E-mail',
                        hint: 'email@exemplo.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      if (!isEdit) ...[
                        const SizedBox(height: 12),
                        _Field(
                          controller: _pwdCtrl,
                          label: 'Senha de Acesso',
                          hint: 'Crie uma senha',
                          obscureText: true,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                        ),
                      ],
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _submit,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: orange,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [orangeButtonShadow],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Salvar',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.dmSans(fontSize: 14, color: textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
            filled: true,
            fillColor: bgPage,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: navyDark),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: red),
            ),
          ),
        ),
      ],
    );
  }
}

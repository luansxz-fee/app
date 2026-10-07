# MedSync Flutter

Aplicativo Flutter do MedSync, conectado ao backend oficial do projeto.

## Visual
- Identidade visual mantida em azul MedSync (#2563EB).
- Logo original reproduzida no app e nos ícones Android.
- Interface responsiva para celular e telas largas.
- Tema claro/escuro.
- Modo de acessibilidade com escala de texto ampliada.
- Componentes com estados de carregamento, vazio, sucesso e erro.

## Funcionalidades
- Login e cadastro.
- Dashboard com progresso diário e adesão.
- Cadastro e edição de medicamentos.
- Horários usando seletor de horário nativo.
- Ativar/pausar medicamento.
- Excluir medicamento com confirmação.
- Registrar dose como tomada.
- Histórico de registros e métricas de adesão.
- Edição de perfil.
- Exportação/compartilhamento dos dados.
- Persistência de sessão e preferências.

## Backend
A API está configurada para:
`https://medsync-backend-oqms.onrender.com/api`

## Rodar no Windows
Na pasta do projeto:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run
```

Para Android, confirme que o Android SDK/NDK necessários estão instalados. O projeto solicita NDK `28.2.13676358`.
"# app" 
"# app" 
"# app" 
